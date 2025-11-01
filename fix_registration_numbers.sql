-- Script SQL pour corriger et réinitialiser les numéros d'enregistrement
-- Ce script s'assure que chaque compétition a ses numéros qui commencent par 1

-- 1. Vérifier l'état actuel des numéros d'enregistrement
SELECT 
    cv.id as competition_id,
    cv.name as competition_name,
    COUNT(p.id) as total_participants,
    MIN(p.registration_number) as min_registration_number,
    MAX(p.registration_number) as max_registration_number,
    COUNT(DISTINCT p.registration_number) as unique_registration_numbers
FROM competition_versions cv
LEFT JOIN participants p ON p.competition_id = cv.id
WHERE p.registration_number IS NOT NULL
GROUP BY cv.id, cv.name
ORDER BY cv.name;

-- 2. Identifier les participants avec des numéros NULL ou problématiques
SELECT 
    cv.name as competition_name,
    p.id as participant_id,
    p.full_name,
    p.registration_number,
    p.created_at
FROM participants p
JOIN competition_versions cv ON cv.id = p.competition_id
WHERE p.registration_number IS NULL 
   OR p.registration_number <= 0
ORDER BY cv.name, p.created_at;

-- 3. Fonction pour réinitialiser les numéros d'enregistrement par compétition
CREATE OR REPLACE FUNCTION reset_registration_numbers_for_competition(comp_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    participant_record RECORD;
    new_number INTEGER := 1;
    updated_count INTEGER := 0;
BEGIN
    -- Réinitialiser les numéros pour cette compétition
    -- Trier par date de création pour maintenir l'ordre chronologique
    FOR participant_record IN 
        SELECT id, full_name, created_at
        FROM participants 
        WHERE competition_id = comp_id
        ORDER BY created_at ASC
    LOOP
        UPDATE participants 
        SET registration_number = new_number
        WHERE id = participant_record.id;
        
        new_number := new_number + 1;
        updated_count := updated_count + 1;
    END LOOP;
    
    RETURN updated_count;
END;
$$;

-- 4. Réinitialiser les numéros pour toutes les compétitions
DO $$
DECLARE
    comp_record RECORD;
    total_updated INTEGER := 0;
BEGIN
    FOR comp_record IN 
        SELECT id, name 
        FROM competition_versions 
        ORDER BY name
    LOOP
        DECLARE
            updated_count INTEGER;
        BEGIN
            updated_count := reset_registration_numbers_for_competition(comp_record.id);
            total_updated := total_updated + updated_count;
            
            RAISE NOTICE 'Compétition "%": % participants mis à jour', 
                        comp_record.name, updated_count;
        END;
    END LOOP;
    
    RAISE NOTICE 'Total: % participants mis à jour', total_updated;
END $$;

-- 5. Vérifier le résultat après réinitialisation
SELECT 
    cv.id as competition_id,
    cv.name as competition_name,
    COUNT(p.id) as total_participants,
    MIN(p.registration_number) as min_registration_number,
    MAX(p.registration_number) as max_registration_number,
    COUNT(DISTINCT p.registration_number) as unique_registration_numbers,
    CASE 
        WHEN COUNT(p.id) = 0 THEN 'Aucun participant'
        WHEN MIN(p.registration_number) = 1 AND 
             MAX(p.registration_number) = COUNT(p.id) AND
             COUNT(DISTINCT p.registration_number) = COUNT(p.id) 
        THEN '✅ Correct'
        ELSE '❌ Problème détecté'
    END as status
FROM competition_versions cv
LEFT JOIN participants p ON p.competition_id = cv.id
WHERE p.registration_number IS NOT NULL
GROUP BY cv.id, cv.name
ORDER BY cv.name;

-- 6. Afficher les participants avec leurs nouveaux numéros
SELECT 
    cv.name as competition_name,
    p.registration_number,
    p.full_name,
    p.age_group,
    p.created_at
FROM participants p
JOIN competition_versions cv ON cv.id = p.competition_id
WHERE p.registration_number IS NOT NULL
ORDER BY cv.name, p.registration_number;

-- 7. Nettoyer la fonction temporaire
DROP FUNCTION IF EXISTS reset_registration_numbers_for_competition(UUID);

-- 8. Commentaires pour la documentation
COMMENT ON COLUMN participants.registration_number IS 'Numéro d''enregistrement unique par compétition, commence toujours par 1';
