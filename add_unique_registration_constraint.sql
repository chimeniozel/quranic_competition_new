-- Script SQL pour ajouter une contrainte unique sur les numéros d'enregistrement
-- Ce script empêche les numéros dupliqués au niveau de la base de données

-- 1. Ajouter une contrainte unique sur (competition_id, registration_number)
-- Cela empêche deux participants d'avoir le même numéro dans la même compétition
ALTER TABLE participants 
ADD CONSTRAINT unique_registration_number_per_competition 
UNIQUE (competition_id, registration_number);

-- 2. Créer un index pour améliorer les performances de recherche
CREATE INDEX IF NOT EXISTS idx_participants_competition_registration 
ON participants(competition_id, registration_number);

-- 3. Créer un index pour améliorer les performances de tri
CREATE INDEX IF NOT EXISTS idx_participants_registration_number 
ON participants(registration_number);

-- 4. Vérifier s'il y a des doublons existants avant d'ajouter la contrainte
-- (Cette requête peut être exécutée pour identifier les problèmes)
/*
SELECT 
    competition_id,
    registration_number,
    COUNT(*) as duplicate_count
FROM participants 
WHERE registration_number IS NOT NULL
GROUP BY competition_id, registration_number
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;
*/

-- 5. Si des doublons existent, les corriger avec cette requête
-- (À exécuter seulement si des doublons sont détectés)
/*
WITH ranked_participants AS (
    SELECT 
        id,
        competition_id,
        registration_number,
        ROW_NUMBER() OVER (
            PARTITION BY competition_id, registration_number 
            ORDER BY created_at ASC
        ) as rn
    FROM participants
    WHERE registration_number IS NOT NULL
),
duplicates AS (
    SELECT id, competition_id, registration_number
    FROM ranked_participants
    WHERE rn > 1
)
UPDATE participants 
SET registration_number = (
    SELECT COALESCE(MAX(p2.registration_number), 0) + 1
    FROM participants p2
    WHERE p2.competition_id = participants.competition_id
)
WHERE id IN (SELECT id FROM duplicates);
*/

-- 6. Commentaires pour la documentation
COMMENT ON CONSTRAINT unique_registration_number_per_competition ON participants 
IS 'Empêche les numéros d''enregistrement dupliqués dans la même compétition';

-- 7. Créer une fonction pour vérifier l'intégrité des numéros d'enregistrement
CREATE OR REPLACE FUNCTION check_registration_numbers_integrity()
RETURNS TABLE(
    competition_id UUID,
    competition_name TEXT,
    total_participants BIGINT,
    min_registration_number INTEGER,
    max_registration_number INTEGER,
    expected_count INTEGER,
    actual_count INTEGER,
    has_gaps BOOLEAN
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cv.id as competition_id,
        cv.name as competition_name,
        COUNT(p.id) as total_participants,
        MIN(p.registration_number) as min_registration_number,
        MAX(p.registration_number) as max_registration_number,
        (MAX(p.registration_number) - MIN(p.registration_number) + 1) as expected_count,
        COUNT(DISTINCT p.registration_number) as actual_count,
        (COUNT(DISTINCT p.registration_number) != (MAX(p.registration_number) - MIN(p.registration_number) + 1)) as has_gaps
    FROM competition_versions cv
    LEFT JOIN participants p ON p.competition_id = cv.id AND p.registration_number IS NOT NULL
    GROUP BY cv.id, cv.name
    HAVING COUNT(p.id) > 0
    ORDER BY cv.name;
END;
$$;

-- 8. Exemple d'utilisation de la fonction de vérification
/*
-- Vérifier l'intégrité des numéros d'enregistrement
SELECT * FROM check_registration_numbers_integrity();

-- Voir les participants avec leurs numéros d'enregistrement
SELECT 
    cv.name as competition_name,
    p.full_name,
    p.registration_number,
    p.age_group,
    p.created_at
FROM participants p
JOIN competition_versions cv ON cv.id = p.competition_id
WHERE p.registration_number IS NOT NULL
ORDER BY cv.name, p.registration_number;
*/
