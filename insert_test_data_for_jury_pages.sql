-- Script pour insérer des données de test pour les pages des jurys

-- 1. Vérifier les données existantes
SELECT '=== VÉRIFICATION DES DONNÉES EXISTANTES ===' as info;

-- Vérifier les jurys
SELECT 'Jurys disponibles:' as info;
SELECT id, full_name, email, role FROM profiles WHERE role = 'jury';

-- Vérifier les versions de compétition
SELECT 'Versions de compétition:' as info;
SELECT id, name, year, is_active, jury_evaluation_enabled FROM competition_versions ORDER BY year DESC;

-- Vérifier les rounds
SELECT 'Rounds disponibles:' as info;
SELECT r.id, r.number, r.version_id, cv.name as version_name, r.is_active, r.result_is_published
FROM rounds r
JOIN competition_versions cv ON r.version_id = cv.id
ORDER BY cv.year DESC, r.number;

-- Vérifier les assignations actuelles
SELECT 'Assignations actuelles:' as info;
SELECT 
    p.full_name as jury_name,
    r.number as round_number,
    cv.name as version_name,
    rja.created_at
FROM round_jury_assignments rja
JOIN profiles p ON rja.user_id = p.id
JOIN rounds r ON rja.round_id = r.id
JOIN competition_versions cv ON r.version_id = cv.id
WHERE p.role = 'jury'
ORDER BY cv.year DESC, r.number, p.full_name;

-- 2. Insérer des données de test si nécessaire
-- (Décommentez et adaptez selon vos besoins)

/*
-- Assigner tous les jurys au round 1 de toutes les versions actives
INSERT INTO round_jury_assignments (user_id, round_id, created_at)
SELECT 
    p.id as user_id,
    r.id as round_id,
    NOW() as created_at
FROM profiles p
CROSS JOIN rounds r
JOIN competition_versions cv ON r.version_id = cv.id
WHERE p.role = 'jury'
  AND r.number = 1  -- Seulement le round 1
  AND cv.is_active = true  -- Seulement les versions actives
  AND NOT EXISTS (
      SELECT 1 FROM round_jury_assignments rja 
      WHERE rja.user_id = p.id AND rja.round_id = r.id
  );
*/

-- 3. Vérifier les assignations après insertion
SELECT '=== ASSIGNATIONS APRÈS INSERTION ===' as info;
SELECT 
    p.full_name as jury_name,
    r.number as round_number,
    cv.name as version_name,
    rja.created_at
FROM round_jury_assignments rja
JOIN profiles p ON rja.user_id = p.id
JOIN rounds r ON rja.round_id = r.id
JOIN competition_versions cv ON r.version_id = cv.id
WHERE p.role = 'jury'
ORDER BY cv.year DESC, r.number, p.full_name;

-- 4. Vérifier les participants pour les tests
SELECT 'Participants disponibles:' as info;
SELECT 
    p.id,
    p.registration_number,
    p.full_name,
    p.age_group,
    p.is_accepted,
    pv.version_id,
    cv.name as version_name
FROM participants p
JOIN participant_versions pv ON p.id = pv.participant_id
JOIN competition_versions cv ON pv.version_id = cv.id
WHERE p.is_accepted = true
ORDER BY cv.year DESC, p.age_group, p.registration_number;

-- 5. Vérifier les évaluations existantes
SELECT 'Évaluations existantes:' as info;
SELECT 
    e.id,
    p.full_name as jury_name,
    part.full_name as participant_name,
    r.number as round_number,
    cv.name as version_name,
    e.total_score,
    e.created_at
FROM evaluations e
JOIN profiles p ON e.jury_id = p.id
JOIN participants part ON e.participant_id = part.id
JOIN rounds r ON e.round_id = r.id
JOIN competition_versions cv ON r.version_id = cv.id
WHERE p.role = 'jury'
ORDER BY cv.year DESC, r.number, p.full_name;
