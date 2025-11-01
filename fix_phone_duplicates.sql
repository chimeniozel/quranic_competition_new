-- Script SQL pour vérifier et corriger les données existantes
-- Ce script vérifie s'il y a des conflits de numéros de téléphone et les résout

-- 1. Vérifier l'état actuel des numéros de téléphone
SELECT 
    'État actuel des numéros de téléphone' as description,
    COUNT(DISTINCT phone) as unique_phones,
    COUNT(*) as total_participants,
    COUNT(DISTINCT competition_id) as total_competitions
FROM participants
WHERE phone IS NOT NULL;

-- 2. Identifier les numéros de téléphone utilisés dans plusieurs compétitions
SELECT 
    'Numéros utilisés dans plusieurs compétitions' as description,
    p.phone,
    COUNT(DISTINCT p.competition_id) as competitions_count,
    STRING_AGG(DISTINCT cv.name, ', ') as competition_names,
    COUNT(p.id) as total_participants
FROM participants p
JOIN competition_versions cv ON cv.id = p.competition_id
WHERE p.phone IS NOT NULL
GROUP BY p.phone
HAVING COUNT(DISTINCT p.competition_id) > 1
ORDER BY competitions_count DESC, total_participants DESC;

-- 3. Identifier les doublons de numéros de téléphone dans la même compétition
SELECT 
    'Doublons dans la même compétition' as description,
    cv.name as competition_name,
    p.phone,
    COUNT(p.id) as duplicate_count,
    STRING_AGG(p.full_name, ', ') as participant_names
FROM participants p
JOIN competition_versions cv ON cv.id = p.competition_id
WHERE p.phone IS NOT NULL
GROUP BY cv.id, cv.name, p.phone
HAVING COUNT(p.id) > 1
ORDER BY cv.name, duplicate_count DESC;

-- 4. Fonction pour corriger les doublons dans la même compétition
CREATE OR REPLACE FUNCTION fix_phone_duplicates_in_competition(comp_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    duplicate_record RECORD;
    fixed_count INTEGER := 0;
    new_phone TEXT;
    phone_counter INTEGER;
    participant_ids TEXT[];
    participant_id TEXT;
BEGIN
    -- Trouver tous les doublons dans cette compétition
    FOR duplicate_record IN 
        SELECT 
            p.phone,
            COUNT(p.id) as duplicate_count,
            MIN(p.created_at) as first_created,
            ARRAY_AGG(p.id::TEXT ORDER BY p.created_at ASC) as participant_ids
        FROM participants p
        WHERE p.competition_id = comp_id 
            AND p.phone IS NOT NULL
        GROUP BY p.phone
        HAVING COUNT(p.id) > 1
        ORDER BY first_created ASC
    LOOP
        -- Pour chaque numéro dupliqué, modifier les participants suivants
        phone_counter := 1;
        participant_ids := duplicate_record.participant_ids;
        
        FOREACH participant_id IN ARRAY participant_ids
        LOOP
            IF phone_counter > 1 THEN
                -- Modifier le numéro de téléphone en ajoutant un suffixe
                new_phone := duplicate_record.phone || '_' || phone_counter::TEXT;
                
                UPDATE participants 
                SET phone = new_phone
                WHERE id = participant_id::UUID;
                
                fixed_count := fixed_count + 1;
                
                RAISE NOTICE 'Participant %: numéro modifié de % vers %', 
                            participant_id, duplicate_record.phone, new_phone;
            END IF;
            
            phone_counter := phone_counter + 1;
        END LOOP;
    END LOOP;
    
    RETURN fixed_count;
END;
$$;

-- 5. Corriger tous les doublons dans toutes les compétitions
DO $$
DECLARE
    comp_record RECORD;
    total_fixed INTEGER := 0;
BEGIN
    FOR comp_record IN 
        SELECT id, name 
        FROM competition_versions 
        ORDER BY name
    LOOP
        DECLARE
            fixed_count INTEGER;
        BEGIN
            fixed_count := fix_phone_duplicates_in_competition(comp_record.id);
            total_fixed := total_fixed + fixed_count;
            
            IF fixed_count > 0 THEN
                RAISE NOTICE 'Compétition "%": % doublons corrigés', 
                            comp_record.name, fixed_count;
            END IF;
        END;
    END LOOP;
    
    RAISE NOTICE 'Total: % doublons corrigés', total_fixed;
END $$;

-- 6. Vérifier le résultat après correction
SELECT 
    'Après correction - Doublons restants' as description,
    COUNT(*) as remaining_duplicates
FROM (
    SELECT 
        cv.name as competition_name,
        p.phone,
        COUNT(p.id) as duplicate_count
    FROM participants p
    JOIN competition_versions cv ON cv.id = p.competition_id
    WHERE p.phone IS NOT NULL
    GROUP BY cv.id, cv.name, p.phone
    HAVING COUNT(p.id) > 1
) duplicates;

-- 7. Afficher les participants avec leurs numéros de téléphone finaux
SELECT 
    cv.name as competition_name,
    p.full_name,
    p.phone,
    p.registration_number,
    p.age_group,
    p.created_at
FROM participants p
JOIN competition_versions cv ON cv.id = p.competition_id
WHERE p.phone IS NOT NULL
ORDER BY cv.name, p.phone, p.created_at;

-- 8. Statistiques finales
SELECT 
    'Statistiques finales' as description,
    COUNT(DISTINCT phone) as unique_phones,
    COUNT(*) as total_participants,
    COUNT(DISTINCT competition_id) as total_competitions,
    COUNT(DISTINCT CONCAT(competition_id, '_', phone)) as unique_competition_phone_combinations
FROM participants
WHERE phone IS NOT NULL;

-- 9. Nettoyer la fonction temporaire
DROP FUNCTION IF EXISTS fix_phone_duplicates_in_competition(UUID);

-- 10. Commentaires pour la documentation
COMMENT ON COLUMN participants.phone IS 'Numéro de téléphone unique par compétition, peut être réutilisé dans différentes compétitions';
