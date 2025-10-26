-- Script pour créer la nouvelle structure: relation entre users (jury) et rounds
-- Au lieu de: users (jury) <-> competition_version
-- Maintenant: users (jury) <-> rounds

-- 1. Créer la nouvelle table round_jury_assignments
CREATE TABLE IF NOT EXISTS round_jury_assignments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    round_id UUID NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Contrainte unique: un jury ne peut être assigné qu'une fois par round
    UNIQUE(user_id, round_id)
);

-- 2. Créer les index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_round_jury_assignments_user_id ON round_jury_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_round_jury_assignments_round_id ON round_jury_assignments(round_id);
CREATE INDEX IF NOT EXISTS idx_round_jury_assignments_created_at ON round_jury_assignments(created_at);

-- 3. Ajouter les contraintes de clé étrangère explicites
ALTER TABLE round_jury_assignments 
ADD CONSTRAINT round_jury_assignments_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE round_jury_assignments 
ADD CONSTRAINT round_jury_assignments_round_id_fkey 
FOREIGN KEY (round_id) REFERENCES rounds(id) ON DELETE CASCADE;

-- 4. Créer une fonction pour migrer les données existantes
CREATE OR REPLACE FUNCTION migrate_jury_assignments_to_rounds()
RETURNS void AS $$
DECLARE
    assignment_record RECORD;
    round_record RECORD;
BEGIN
    -- Pour chaque assignment existant dans jury_assignments
    FOR assignment_record IN 
        SELECT ja.user_id, ja.version_id, ja.created_at
        FROM jury_assignments ja
        WHERE ja.user_id IS NOT NULL 
        AND ja.version_id IS NOT NULL
    LOOP
        -- Trouver tous les rounds de cette version
        FOR round_record IN 
            SELECT r.id, r.number, r.name
            FROM rounds r
            WHERE r.version_id = assignment_record.version_id
            ORDER BY r.number
        LOOP
            -- Insérer l'assignment pour ce round (si pas déjà existant)
            INSERT INTO round_jury_assignments (user_id, round_id, created_at)
            VALUES (assignment_record.user_id, round_record.id, assignment_record.created_at)
            ON CONFLICT (user_id, round_id) DO NOTHING;
            
            RAISE NOTICE 'Migré: Jury % assigné au round % (%)', 
                assignment_record.user_id, 
                round_record.number, 
                COALESCE(round_record.name, 'Sans nom');
        END LOOP;
    END LOOP;
    
    RAISE NOTICE 'Migration terminée avec succès';
END;
$$ LANGUAGE plpgsql;

-- 5. Exécuter la migration
SELECT migrate_jury_assignments_to_rounds();

-- 6. Vérifier les données migrées
SELECT 
    rja.id,
    rja.user_id,
    rja.round_id,
    p.full_name as jury_name,
    p.role,
    r.number as round_number,
    r.name as round_name,
    cv.name as version_name,
    rja.created_at
FROM round_jury_assignments rja
JOIN profiles p ON rja.user_id = p.id
JOIN rounds r ON rja.round_id = r.id
JOIN competition_versions cv ON r.version_id = cv.id
ORDER BY cv.name, r.number, p.full_name;

-- 7. Statistiques de migration
SELECT 
    'Assignments migrés' as description,
    COUNT(*) as count
FROM round_jury_assignments
UNION ALL
SELECT 
    'Jurys uniques' as description,
    COUNT(DISTINCT user_id) as count
FROM round_jury_assignments
UNION ALL
SELECT 
    'Rounds avec jurys' as description,
    COUNT(DISTINCT round_id) as count
FROM round_jury_assignments;

-- 8. Nettoyer la fonction de migration (optionnel)
-- DROP FUNCTION IF EXISTS migrate_jury_assignments_to_rounds();

-- 9. Créer une vue pour faciliter les requêtes
CREATE OR REPLACE VIEW jury_round_assignments_view AS
SELECT 
    rja.id as assignment_id,
    rja.user_id as jury_id,
    rja.round_id,
    p.full_name as jury_name,
    p.phone as jury_phone,
    p.email as jury_email,
    p.role,
    r.number as round_number,
    r.name as round_name,
    r.version_id,
    cv.name as version_name,
    cv.year as version_year,
    rja.created_at as assigned_at
FROM round_jury_assignments rja
JOIN profiles p ON rja.user_id = p.id
JOIN rounds r ON rja.round_id = r.id
JOIN competition_versions cv ON r.version_id = cv.id
WHERE p.role = 'jury';

-- 10. Vérification finale de la structure
SELECT 
    'round_jury_assignments' as table_name,
    COUNT(*) as total_assignments,
    COUNT(DISTINCT user_id) as unique_jurys,
    COUNT(DISTINCT round_id) as unique_rounds
FROM round_jury_assignments;
