-- Script pour corriger les problèmes de limites de participants
-- Ce script identifie et corrige les incohérences entre les limites et le nombre de participants

-- 1. Vérifier les versions avec des problèmes de limites
SELECT 
    cv.id,
    cv.name,
    cv.max_adults,
    cv.max_children,
    COUNT(CASE WHEN p.age_group = 'كبار' THEN 1 END) as current_adults,
    COUNT(CASE WHEN p.age_group = 'صغار' THEN 1 END) as current_children,
    COUNT(p.id) as total_participants
FROM competition_versions cv
LEFT JOIN participants p ON p.competition_id = cv.id
WHERE cv.is_active = true
GROUP BY cv.id, cv.name, cv.max_adults, cv.max_children
HAVING 
    COUNT(CASE WHEN p.age_group = 'كبار' THEN 1 END) > cv.max_adults
    OR COUNT(CASE WHEN p.age_group = 'صغار' THEN 1 END) > cv.max_children
ORDER BY cv.name;

-- 2. Identifier les participants en excès (optionnel - pour information)
-- Décommentez cette section si vous voulez voir quels participants sont en excès

/*
SELECT 
    cv.name as version_name,
    p.full_name,
    p.age_group,
    p.created_at,
    ROW_NUMBER() OVER (
        PARTITION BY cv.id, p.age_group 
        ORDER BY p.created_at DESC
    ) as participant_rank
FROM competition_versions cv
JOIN participants p ON p.competition_id = cv.id
WHERE cv.is_active = true
ORDER BY cv.name, p.age_group, p.created_at DESC;
*/

-- 3. Mettre à jour les limites pour accommoder les participants actuels
-- ATTENTION: Cette section modifie les limites pour s'adapter au nombre actuel de participants
-- Décommentez et modifiez selon vos besoins

/*
-- Exemple: Augmenter les limites pour accommoder tous les participants actuels
UPDATE competition_versions 
SET 
    max_adults = (
        SELECT COUNT(*) 
        FROM participants p 
        WHERE p.competition_id = competition_versions.id 
        AND p.age_group = 'كبار'
    ),
    max_children = (
        SELECT COUNT(*) 
        FROM participants p 
        WHERE p.competition_id = competition_versions.id 
        AND p.age_group = 'صغار'
    )
WHERE id IN (
    SELECT cv.id
    FROM competition_versions cv
    LEFT JOIN participants p ON p.competition_id = cv.id
    WHERE cv.is_active = true
    GROUP BY cv.id
    HAVING 
        COUNT(CASE WHEN p.age_group = 'كبار' THEN 1 END) > cv.max_adults
        OR COUNT(CASE WHEN p.age_group = 'صغار' THEN 1 END) > cv.max_children
);
*/

-- 4. Alternative: Supprimer les participants en excès (ATTENTION: DESTRUCTIF)
-- Décommentez cette section SEULEMENT si vous voulez supprimer les participants en excès
-- ATTENTION: Cette opération est IRRÉVERSIBLE

/*
-- Supprimer les participants adultes en excès (garder les plus récents)
DELETE FROM participants 
WHERE id IN (
    SELECT p.id
    FROM participants p
    JOIN competition_versions cv ON cv.id = p.competition_id
    WHERE p.age_group = 'كبار'
    AND cv.is_active = true
    AND p.id NOT IN (
        SELECT p2.id
        FROM participants p2
        JOIN competition_versions cv2 ON cv2.id = p2.competition_id
        WHERE p2.age_group = 'كبار'
        AND cv2.is_active = true
        AND p2.competition_id = p.competition_id
        ORDER BY p2.created_at DESC
        LIMIT cv2.max_adults
    )
);

-- Supprimer les participants enfants en excès (garder les plus récents)
DELETE FROM participants 
WHERE id IN (
    SELECT p.id
    FROM participants p
    JOIN competition_versions cv ON cv.id = p.competition_id
    WHERE p.age_group = 'صغار'
    AND cv.is_active = true
    AND p.id NOT IN (
        SELECT p2.id
        FROM participants p2
        JOIN competition_versions cv2 ON cv2.id = p2.competition_id
        WHERE p2.age_group = 'صغار'
        AND cv2.is_active = true
        AND p2.competition_id = p.competition_id
        ORDER BY p2.created_at DESC
        LIMIT cv2.max_children
    )
);
*/

-- 5. Vérification finale après correction
SELECT 
    cv.id,
    cv.name,
    cv.max_adults,
    cv.max_children,
    COUNT(CASE WHEN p.age_group = 'كبار' THEN 1 END) as current_adults,
    COUNT(CASE WHEN p.age_group = 'صغار' THEN 1 END) as current_children,
    CASE 
        WHEN COUNT(CASE WHEN p.age_group = 'كبار' THEN 1 END) <= cv.max_adults 
        AND COUNT(CASE WHEN p.age_group = 'صغار' THEN 1 END) <= cv.max_children
        THEN '✅ OK'
        ELSE '❌ PROBLÈME'
    END as status
FROM competition_versions cv
LEFT JOIN participants p ON p.competition_id = cv.id
WHERE cv.is_active = true
GROUP BY cv.id, cv.name, cv.max_adults, cv.max_children
ORDER BY cv.name;
