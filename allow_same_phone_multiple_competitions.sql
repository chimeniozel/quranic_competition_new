-- Script SQL pour permettre le même numéro de téléphone dans différentes compétitions
-- Ce script modifie la contrainte unique pour permettre la réutilisation des numéros de téléphone

-- 1. Vérifier les contraintes actuelles sur la table participants
SELECT 
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    tc.table_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'participants'
    AND tc.constraint_type = 'UNIQUE'
ORDER BY tc.constraint_name;

-- 2. Vérifier s'il y a des doublons de numéros de téléphone dans différentes compétitions
SELECT 
    p.phone,
    COUNT(DISTINCT p.competition_id) as competitions_count,
    COUNT(p.id) as total_participants,
    STRING_AGG(DISTINCT cv.name, ', ') as competition_names
FROM participants p
JOIN competition_versions cv ON cv.id = p.competition_id
GROUP BY p.phone
HAVING COUNT(DISTINCT p.competition_id) > 1
ORDER BY competitions_count DESC;

-- 3. Supprimer l'ancienne contrainte unique sur le numéro de téléphone (si elle existe)
-- Note: Cette commande peut échouer si la contrainte n'existe pas, c'est normal
ALTER TABLE participants 
DROP CONSTRAINT IF EXISTS participants_phone_key;

-- 4. Créer une nouvelle contrainte unique sur (competition_id, phone)
-- Cela permet le même numéro de téléphone dans différentes compétitions
-- mais empêche les doublons dans la même compétition
ALTER TABLE participants 
ADD CONSTRAINT unique_phone_per_competition 
UNIQUE (competition_id, phone);

-- 5. Créer un index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_participants_competition_phone 
ON participants(competition_id, phone);

-- 6. Vérifier le résultat après modification
SELECT 
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    tc.table_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'participants'
    AND tc.constraint_type = 'UNIQUE'
ORDER BY tc.constraint_name;

-- 7. Tester la nouvelle contrainte avec des données d'exemple
-- (Ces requêtes sont commentées pour éviter les erreurs en cas de données existantes)
/*
-- Test 1: Même numéro dans différentes compétitions (devrait fonctionner)
INSERT INTO participants (
    id, full_name, gender, birth_date, phone, quran_memized, 
    reading_methods, residence, has_ijaza, won_previous_ranks, 
    participated_before, age_group, created_at, is_accepted, 
    competition_id, registration_number
) VALUES (
    gen_random_uuid(), 'Test Participant 1', 'ذكر', '1990-01-01', 
    '123456789', '30 جزء', '1', 'نواكشوط', false, false, false, 
    'كبار', NOW(), true, 'competition-1', 1
);

INSERT INTO participants (
    id, full_name, gender, birth_date, phone, quran_memized, 
    reading_methods, residence, has_ijaza, won_previous_ranks, 
    participated_before, age_group, created_at, is_accepted, 
    competition_id, registration_number
) VALUES (
    gen_random_uuid(), 'Test Participant 2', 'أنثى', '1995-01-01', 
    '123456789', '30 جزء', '1', 'نواكشوط', false, false, false, 
    'كبار', NOW(), true, 'competition-2', 1
);

-- Test 2: Même numéro dans la même compétition (devrait échouer)
INSERT INTO participants (
    id, full_name, gender, birth_date, phone, quran_memized, 
    reading_methods, residence, has_ijaza, won_previous_ranks, 
    participated_before, age_group, created_at, is_accepted, 
    competition_id, registration_number
) VALUES (
    gen_random_uuid(), 'Test Participant 3', 'ذكر', '1992-01-01', 
    '123456789', '30 جزء', '1', 'نواكشوط', false, false, false, 
    'كبار', NOW(), true, 'competition-1', 2
);
*/

-- 8. Fonction pour vérifier l'intégrité des numéros de téléphone
CREATE OR REPLACE FUNCTION check_phone_integrity()
RETURNS TABLE(
    competition_id UUID,
    competition_name TEXT,
    phone TEXT,
    participant_count BIGINT,
    participant_names TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cv.id as competition_id,
        cv.name as competition_name,
        p.phone,
        COUNT(p.id) as participant_count,
        STRING_AGG(p.full_name, ', ') as participant_names
    FROM participants p
    JOIN competition_versions cv ON cv.id = p.competition_id
    GROUP BY cv.id, cv.name, p.phone
    HAVING COUNT(p.id) > 1
    ORDER BY cv.name, p.phone;
END;
$$;

-- 9. Exemple d'utilisation de la fonction de vérification
/*
-- Vérifier s'il y a des doublons de numéros de téléphone dans la même compétition
SELECT * FROM check_phone_integrity();
*/

-- 10. Commentaires pour la documentation
COMMENT ON CONSTRAINT unique_phone_per_competition ON participants 
IS 'Permet le même numéro de téléphone dans différentes compétitions mais empêche les doublons dans la même compétition';

COMMENT ON FUNCTION check_phone_integrity() IS 'Vérifie l''intégrité des numéros de téléphone par compétition';

