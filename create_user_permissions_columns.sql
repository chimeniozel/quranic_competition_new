-- =====================================================
-- Script pour ajouter les colonnes de permissions utilisateur
-- à la table profiles
-- =====================================================

-- 1. Ajouter les colonnes de permissions à la table profiles
-- Ces colonnes sont nullable pour permettre une migration progressive
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS can_create_versions BOOLEAN DEFAULT NULL,
ADD COLUMN IF NOT EXISTS can_publish_content BOOLEAN DEFAULT NULL,
ADD COLUMN IF NOT EXISTS can_validate_accounts BOOLEAN DEFAULT NULL,
ADD COLUMN IF NOT EXISTS can_delete BOOLEAN DEFAULT NULL,
ADD COLUMN IF NOT EXISTS can_modify BOOLEAN DEFAULT NULL,
ADD COLUMN IF NOT EXISTS can_modify_versions BOOLEAN DEFAULT NULL,
ADD COLUMN IF NOT EXISTS can_assign_roles BOOLEAN DEFAULT NULL,
ADD COLUMN IF NOT EXISTS can_view_content BOOLEAN DEFAULT NULL;

-- 2. Initialiser les permissions par défaut selon le rôle existant
-- Super Admin: toutes les permissions activées
UPDATE profiles
SET 
  can_create_versions = true,
  can_publish_content = true,
  can_validate_accounts = true,
  can_delete = true,
  can_modify = true,
  can_modify_versions = true,
  can_assign_roles = true,
  can_view_content = true
WHERE role = 'super_admin'
  AND (can_create_versions IS NULL OR can_publish_content IS NULL);

-- Admin: permissions limitées (pas de suppression/modification/assignation de rôles)
UPDATE profiles
SET 
  can_create_versions = true,
  can_publish_content = true,
  can_validate_accounts = true,
  can_delete = false,
  can_modify = false,
  can_modify_versions = false,
  can_assign_roles = false,
  can_view_content = true
WHERE role = 'admin'
  AND (can_create_versions IS NULL OR can_publish_content IS NULL);

-- Jury: seulement voir le contenu
UPDATE profiles
SET 
  can_create_versions = false,
  can_publish_content = false,
  can_validate_accounts = false,
  can_delete = false,
  can_modify = false,
  can_modify_versions = false,
  can_assign_roles = false,
  can_view_content = true
WHERE role = 'jury'
  AND (can_create_versions IS NULL OR can_publish_content IS NULL);

-- Membre (membre_ordinaire, member, participant): seulement voir le contenu
UPDATE profiles
SET 
  can_create_versions = false,
  can_publish_content = false,
  can_validate_accounts = false,
  can_delete = false,
  can_modify = false,
  can_modify_versions = false,
  can_assign_roles = false,
  can_view_content = true
WHERE role IN ('membre', 'membre_ordinaire', 'member', 'participant')
  AND (can_create_versions IS NULL OR can_publish_content IS NULL);

-- 3. Créer une fonction pour initialiser automatiquement les permissions
-- lors de la création d'un nouveau profil
CREATE OR REPLACE FUNCTION initialize_user_permissions()
RETURNS TRIGGER AS $$
BEGIN
  -- Initialiser les permissions selon le rôle
  CASE NEW.role
    WHEN 'super_admin' THEN
      NEW.can_create_versions := true;
      NEW.can_publish_content := true;
      NEW.can_validate_accounts := true;
      NEW.can_delete := true;
      NEW.can_modify := true;
      NEW.can_modify_versions := true;
      NEW.can_assign_roles := true;
      NEW.can_view_content := true;
    WHEN 'admin' THEN
      NEW.can_create_versions := true;
      NEW.can_publish_content := true;
      NEW.can_validate_accounts := true;
      NEW.can_delete := false;
      NEW.can_modify := false;
      NEW.can_modify_versions := false;
      NEW.can_assign_roles := false;
      NEW.can_view_content := true;
    WHEN 'jury' THEN
      NEW.can_create_versions := false;
      NEW.can_publish_content := false;
      NEW.can_validate_accounts := false;
      NEW.can_delete := false;
      NEW.can_modify := false;
      NEW.can_modify_versions := false;
      NEW.can_assign_roles := false;
      NEW.can_view_content := true;
    ELSE -- membre, membre_ordinaire, member, participant
      NEW.can_create_versions := false;
      NEW.can_publish_content := false;
      NEW.can_validate_accounts := false;
      NEW.can_delete := false;
      NEW.can_modify := false;
      NEW.can_modify_versions := false;
      NEW.can_assign_roles := false;
      NEW.can_view_content := true;
  END CASE;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Créer un trigger pour initialiser automatiquement les permissions
-- lors de la création d'un nouveau profil
DROP TRIGGER IF EXISTS trigger_initialize_user_permissions ON profiles;
CREATE TRIGGER trigger_initialize_user_permissions
  BEFORE INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION initialize_user_permissions();

-- 5. Créer un trigger pour mettre à jour les permissions par défaut
-- lors du changement de rôle (si les permissions n'ont pas été personnalisées)
CREATE OR REPLACE FUNCTION update_user_permissions_on_role_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Si le rôle a changé et que les permissions n'ont pas été personnalisées
  -- (toutes les permissions sont NULL ou correspondent aux valeurs par défaut)
  IF OLD.role != NEW.role THEN
    CASE NEW.role
      WHEN 'super_admin' THEN
        -- Ne mettre à jour que si les permissions sont NULL ou correspondent aux anciennes valeurs par défaut
        IF NEW.can_create_versions IS NULL OR NEW.can_create_versions = OLD.can_create_versions THEN
          NEW.can_create_versions := true;
          NEW.can_publish_content := true;
          NEW.can_validate_accounts := true;
          NEW.can_delete := true;
          NEW.can_modify := true;
          NEW.can_modify_versions := true;
          NEW.can_assign_roles := true;
          NEW.can_view_content := true;
        END IF;
      WHEN 'admin' THEN
        IF NEW.can_create_versions IS NULL OR NEW.can_create_versions = OLD.can_create_versions THEN
          NEW.can_create_versions := true;
          NEW.can_publish_content := true;
          NEW.can_validate_accounts := true;
          NEW.can_delete := false;
          NEW.can_modify := false;
          NEW.can_modify_versions := false;
          NEW.can_assign_roles := false;
          NEW.can_view_content := true;
        END IF;
      WHEN 'jury' THEN
        IF NEW.can_create_versions IS NULL OR NEW.can_create_versions = OLD.can_create_versions THEN
          NEW.can_create_versions := false;
          NEW.can_publish_content := false;
          NEW.can_validate_accounts := false;
          NEW.can_delete := false;
          NEW.can_modify := false;
          NEW.can_modify_versions := false;
          NEW.can_assign_roles := false;
          NEW.can_view_content := true;
        END IF;
      ELSE
        IF NEW.can_create_versions IS NULL OR NEW.can_create_versions = OLD.can_create_versions THEN
          NEW.can_create_versions := false;
          NEW.can_publish_content := false;
          NEW.can_validate_accounts := false;
          NEW.can_delete := false;
          NEW.can_modify := false;
          NEW.can_modify_versions := false;
          NEW.can_assign_roles := false;
          NEW.can_view_content := true;
        END IF;
    END CASE;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note: Le trigger pour le changement de rôle est optionnel
-- car vous pouvez vouloir conserver les permissions personnalisées
-- même lors du changement de rôle. Décommentez si nécessaire:
-- DROP TRIGGER IF EXISTS trigger_update_permissions_on_role_change ON profiles;
-- CREATE TRIGGER trigger_update_permissions_on_role_change
--   BEFORE UPDATE ON profiles
--   FOR EACH ROW
--   EXECUTE FUNCTION update_user_permissions_on_role_change();

-- =====================================================
-- Vérification
-- =====================================================
-- Pour vérifier que les colonnes ont été créées:
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'profiles'
--   AND column_name LIKE 'can_%'
-- ORDER BY column_name;

-- Pour vérifier les permissions d'un utilisateur:
-- SELECT id, full_name, role, 
--        can_create_versions, can_publish_content, can_validate_accounts,
--        can_delete, can_modify, can_modify_versions, can_assign_roles, can_view_content
-- FROM profiles
-- WHERE id = 'USER_ID_HERE';

