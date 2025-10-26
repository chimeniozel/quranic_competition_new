-- Script pour ajouter les colonnes de moyenne de succès dans la table competition_versions
-- Ce script ajoute deux nouvelles colonnes pour définir les seuils de passage par groupe d'âge

-- 1. Ajouter les colonnes success_average_adults et success_average_children
ALTER TABLE competition_versions 
ADD COLUMN IF NOT EXISTS success_average_adults DECIMAL(5,2) DEFAULT 70.00,
ADD COLUMN IF NOT EXISTS success_average_children DECIMAL(5,2) DEFAULT 70.00;

-- 2. Ajouter des commentaires pour documenter les colonnes
COMMENT ON COLUMN competition_versions.success_average_adults IS 'Moyenne de succès requise pour les participants adultes (en pourcentage)';
COMMENT ON COLUMN competition_versions.success_average_children IS 'Moyenne de succès requise pour les participants enfants (en pourcentage)';

-- 3. Ajouter des contraintes pour s'assurer que les valeurs sont dans une plage valide (0-100)
ALTER TABLE competition_versions 
ADD CONSTRAINT check_success_average_adults_range 
CHECK (success_average_adults >= 0 AND success_average_adults <= 100);

ALTER TABLE competition_versions 
ADD CONSTRAINT check_success_average_children_range 
CHECK (success_average_children >= 0 AND success_average_children <= 100);

-- 4. Mettre à jour les versions existantes avec des valeurs par défaut appropriées
-- Vous pouvez modifier ces valeurs selon vos besoins
UPDATE competition_versions 
SET 
    success_average_adults = 70.00,
    success_average_children = 70.00
WHERE success_average_adults IS NULL OR success_average_children IS NULL;

-- 5. Vérifier que les colonnes ont été ajoutées correctement
SELECT 
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'competition_versions' 
AND column_name IN ('success_average_adults', 'success_average_children')
ORDER BY column_name;

-- 6. Afficher les données actuelles pour vérification
SELECT 
    id,
    name,
    year,
    max_adults,
    max_children,
    success_average_adults,
    success_average_children,
    is_active
FROM competition_versions
ORDER BY year DESC, name;

-- 7. Exemple de mise à jour d'une version spécifique (décommentez et modifiez selon vos besoins)
/*
UPDATE competition_versions 
SET 
    success_average_adults = 75.00,  -- 75% pour les adultes
    success_average_children = 65.00 -- 65% pour les enfants
WHERE id = 'votre_version_id_ici';
*/
