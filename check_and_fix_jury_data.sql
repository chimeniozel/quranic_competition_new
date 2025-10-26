-- Script pour vérifier et corriger les données des jurys

-- 1. Vérifier les jurys disponibles
SELECT '=== JURYS DISPONIBLES ===' as info;
SELECT id, full_name, email, role 
FROM profiles 
WHERE role = 'jury'
ORDER BY full_name;

-- 2. Vérifier les rounds disponibles
SELECT '=== ROUNDS DISPONIBLES ===' as info;
SELECT r.id, r.number, r.version_id, cv.name as version_name, cv.year
FROM rounds r
JOIN competition_versions cv ON r.version_id = cv.id
ORDER BY cv.year DESC, r.number;

-- 3. Vérifier les assignations actuelles
SELECT '=== ASSIGNATIONS ACTUELLES ===' as info;
SELECT 
    p.full_name as jury_name,
    r.number as round_number,
    cv.name as version_name,
    rja.created_at
FROM round_jury_assignments rja
JOIN profiles p ON rja.user_id = p.id
JOIN rounds r ON rja.round_id = r.id
JOIN competition_versions cv ON r.version_id = cv.id
ORDER BY cv.year DESC, r.number, p.full_name;

-- 4. Si aucune assignation, créer des assignations de test
-- (Décommentez et adaptez selon vos données)

/*
-- Assigner tous les jurys au round 1 de toutes les versions
INSERT INTO round_jury_assignments (user_id, round_id, created_at)
SELECT 
    p.id as user_id,
    r.id as round_id,
    NOW() as created_at
FROM profiles p
CROSS JOIN rounds r
WHERE p.role = 'jury'
  AND r.number = 1  -- Seulement le round 1
  AND NOT EXISTS (
      SELECT 1 FROM round_jury_assignments rja 
      WHERE rja.user_id = p.id AND rja.round_id = r.id
  );
*/

-- 5. Vérifier les assignations après insertion
SELECT '=== ASSIGNATIONS APRÈS CORRECTION ===' as info;
SELECT 
    p.full_name as jury_name,
    r.number as round_number,
    cv.name as version_name,
    rja.created_at
FROM round_jury_assignments rja
JOIN profiles p ON rja.user_id = p.id
JOIN rounds r ON rja.round_id = r.id
JOIN competition_versions cv ON r.version_id = cv.id
ORDER BY cv.year DESC, r.number, p.full_name;
