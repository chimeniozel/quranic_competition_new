-- Script SQL simplifié pour corriger les doublons de numéros de téléphone
-- Version simplifiée qui évite les problèmes de boucles complexes

-- 1. Vérifier l'état actuel des numéros de téléphone
SELECT 
    'État actuel des numéros de téléphone' as description,
    COUNT(DISTINCT phone) as unique_phones,
    COUNT(*) as total_participants,
    COUNT(DISTINCT competition_id) as total_competitions
FROM participants
WHERE phone IS NOT NULL;

-- 2. Identifier les doublons de numéros de téléphone dans la même compétition
SELECT 
    'Doublons dans la même compétition' as description,
    cv.name as competition_name,
    p.phone,
    COUNT(p.id) as duplicate_count,
    STRING_AGG(p.full_name, ', ') as participant_names,
    STRING_AGG(p.id::TEXT, ', ') as participant_ids
FROM participants p
JOIN competition_versions cv ON cv.id = p.competition_id
WHERE p.phone IS NOT NULL
GROUP BY cv.id, cv.name, p.phone
HAVING COUNT(p.id) > 1
ORDER BY cv.name, duplicate_count DESC;

-- 3. Méthode simple : Utiliser une requête UPDATE avec ROW_NUMBER()
-- Cette méthode évite les boucles complexes et utilise une approche SQL pure

-- 3.1. Créer une table temporaire avec les numéros de ligne pour chaque doublon
CREATE TEMP TABLE phone_duplicates AS
SELECT 
    p.id,
    p.competition_id,
    p.phone,
    p.full_name,
    p.created_at,
    ROW_NUMBER() OVER (
        PARTITION BY p.competition_id, p.phone 
        ORDER BY p.created_at ASC
    ) as row_num
FROM participants p
WHERE p.phone IS NOT NULL;

-- 3.2. Identifier les participants qui ont des doublons (row_num > 1)
SELECT 
    'Participants avec doublons détectés' as description,
    COUNT(*) as participants_to_fix
FROM phone_duplicates
WHERE row_num > 1;

-- 3.3. Corriger les doublons en ajoutant un suffixe
UPDATE participants 
SET phone = pd.phone || '_' || pd.row_num::TEXT
FROM phone_duplicates pd
WHERE participants.id = pd.id 
    AND pd.row_num > 1;

-- 3.4. Afficher les corrections effectuées
SELECT 
    'Corrections effectuées' as description,
    pd.competition_id,
    cv.name as competition_name,
    pd.phone as original_phone,
    pd.phone || '_' || pd.row_num::TEXT as new_phone,
    pd.full_name,
    pd.created_at
FROM phone_duplicates pd
JOIN competition_versions cv ON cv.id = pd.competition_id
WHERE pd.row_num > 1
ORDER BY cv.name, pd.phone, pd.created_at;

-- 4. Vérifier le résultat après correction
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

-- 5. Afficher les participants avec leurs numéros de téléphone finaux
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

-- 6. Statistiques finales
SELECT 
    'Statistiques finales' as description,
    COUNT(DISTINCT phone) as unique_phones,
    COUNT(*) as total_participants,
    COUNT(DISTINCT competition_id) as total_competitions,
    COUNT(DISTINCT CONCAT(competition_id, '_', phone)) as unique_competition_phone_combinations
FROM participants
WHERE phone IS NOT NULL;

-- 7. Nettoyer la table temporaire
DROP TABLE IF EXISTS phone_duplicates;

-- 8. Commentaires pour la documentation
COMMENT ON COLUMN participants.phone IS 'Numéro de téléphone unique par compétition, peut être réutilisé dans différentes compétitions';

