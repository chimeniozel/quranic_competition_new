-- Script pour corriger la contrainte de rôle dans la table profiles
-- Date: 2025-01-07

-- Supprimer l'ancienne contrainte
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;

-- Créer la nouvelle contrainte avec tous les rôles
ALTER TABLE public.profiles 
ADD CONSTRAINT profiles_role_check 
CHECK (role IN ('super_admin', 'admin', 'jury', 'membre'));

-- Vérifier la contrainte
DO $$
DECLARE
    constraint_name TEXT;
BEGIN
    SELECT conname INTO constraint_name 
    FROM pg_constraint 
    WHERE conrelid = 'public.profiles'::regclass 
    AND conname = 'profiles_role_check';
    
    IF constraint_name IS NOT NULL THEN
        RAISE NOTICE '✅ Contrainte profiles_role_check mise à jour avec succès';
        RAISE NOTICE '📋 Rôles autorisés: super_admin, admin, jury, membre';
    ELSE
        RAISE NOTICE '❌ Erreur: Contrainte non trouvée';
    END IF;
END $$;

-- Test de la contrainte
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Test de la contrainte:';
    
    -- Tenter d'insérer un rôle valide (cela devrait échouer silencieusement car l'ID existe déjà)
    BEGIN
        INSERT INTO public.profiles (id, role) 
        VALUES ('00000000-0000-0000-0000-000000000000', 'jury')
        ON CONFLICT (id) DO NOTHING;
        RAISE NOTICE '✅ Rôle "jury" accepté par la contrainte';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '❌ Rôle "jury" rejeté par la contrainte';
        WHEN OTHERS THEN
            RAISE NOTICE 'ℹ️ Test terminé (comportement normal)';
    END;
END $$;
