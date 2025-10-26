-- Script pour insérer des données de test pour les assignations de jurys

-- 1. Vérifier s'il y a des jurys dans la table profiles
SELECT 'Jurys disponibles:' as info;
SELECT id, full_name, email, role FROM profiles WHERE role = 'jury';

-- 2. Vérifier s'il y a des rounds dans la table rounds
SELECT 'Rounds disponibles:' as info;
SELECT id, number, version_id, name FROM rounds ORDER BY version_id, number;

-- 3. Insérer des assignations de test (remplacer les IDs par les vrais IDs de votre base)
-- Exemple d'insertion (à adapter selon vos données réelles):

-- INSERT INTO round_jury_assignments (user_id, round_id, created_at)
-- SELECT 
--     p.id as user_id,
--     r.id as round_id,
--     NOW() as created_at
-- FROM profiles p
-- CROSS JOIN rounds r
-- WHERE p.role = 'jury'
--   AND r.number = 1  -- Assigner seulement au round 1 pour commencer
--   AND NOT EXISTS (
--       SELECT 1 FROM round_jury_assignments rja 
--       WHERE rja.user_id = p.id AND rja.round_id = r.id
--   );

-- 4. Vérifier les assignations après insertion
SELECT 'Assignations après insertion:' as info;
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
