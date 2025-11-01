-- Script pour implémenter la suppression en cascade des compétitions
-- Ce script configure les contraintes de clés étrangères pour supprimer automatiquement
-- tous les éléments liés lorsqu'une compétition est supprimée

-- 1. Vérifier les contraintes existantes
SELECT 
    tc.table_name, 
    tc.constraint_name, 
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
LEFT JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
LEFT JOIN information_schema.referential_constraints AS rc
    ON tc.constraint_name = rc.constraint_name
    AND tc.table_schema = rc.constraint_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND ccu.table_name = 'competition_versions'
ORDER BY tc.table_name, tc.constraint_name;

-- 2. Supprimer les contraintes existantes (si nécessaire)
-- Décommentez ces lignes si vous voulez recréer les contraintes

/*
-- Supprimer les contraintes existantes
ALTER TABLE participants DROP CONSTRAINT IF EXISTS participants_competition_id_fkey;
ALTER TABLE rounds DROP CONSTRAINT IF EXISTS rounds_version_id_fkey;
ALTER TABLE round_jury_assignments DROP CONSTRAINT IF EXISTS round_jury_assignments_round_id_fkey;
ALTER TABLE evaluations DROP CONSTRAINT IF EXISTS evaluations_round_id_fkey;
ALTER TABLE evaluations DROP CONSTRAINT IF EXISTS evaluations_participant_id_fkey;
ALTER TABLE round_results DROP CONSTRAINT IF EXISTS round_results_round_id_fkey;
ALTER TABLE round_results DROP CONSTRAINT IF EXISTS round_results_participant_id_fkey;
ALTER TABLE round_results DROP CONSTRAINT IF EXISTS round_results_version_id_fkey;
*/

-- 3. Créer les contraintes avec suppression en cascade
-- Participants -> Competition Versions
ALTER TABLE participants 
ADD CONSTRAINT participants_competition_id_fkey 
FOREIGN KEY (competition_id) 
REFERENCES competition_versions(id) 
ON DELETE CASCADE;

-- Rounds -> Competition Versions
ALTER TABLE rounds 
ADD CONSTRAINT rounds_version_id_fkey 
FOREIGN KEY (version_id) 
REFERENCES competition_versions(id) 
ON DELETE CASCADE;

-- Round Jury Assignments -> Rounds
ALTER TABLE round_jury_assignments 
ADD CONSTRAINT round_jury_assignments_round_id_fkey 
FOREIGN KEY (round_id) 
REFERENCES rounds(id) 
ON DELETE CASCADE;

-- Evaluations -> Rounds
ALTER TABLE evaluations 
ADD CONSTRAINT evaluations_round_id_fkey 
FOREIGN KEY (round_id) 
REFERENCES rounds(id) 
ON DELETE CASCADE;

-- Evaluations -> Participants
ALTER TABLE evaluations 
ADD CONSTRAINT evaluations_participant_id_fkey 
FOREIGN KEY (participant_id) 
REFERENCES participants(id) 
ON DELETE CASCADE;

-- Round Results -> Rounds
ALTER TABLE round_results 
ADD CONSTRAINT round_results_round_id_fkey 
FOREIGN KEY (round_id) 
REFERENCES rounds(id) 
ON DELETE CASCADE;

-- Round Results -> Participants
ALTER TABLE round_results 
ADD CONSTRAINT round_results_participant_id_fkey 
FOREIGN KEY (participant_id) 
REFERENCES participants(id) 
ON DELETE CASCADE;

-- Round Results -> Competition Versions
ALTER TABLE round_results 
ADD CONSTRAINT round_results_version_id_fkey 
FOREIGN KEY (version_id) 
REFERENCES competition_versions(id) 
ON DELETE CASCADE;

-- 4. Vérifier les nouvelles contraintes
SELECT 
    tc.table_name, 
    tc.constraint_name, 
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
LEFT JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
LEFT JOIN information_schema.referential_constraints AS rc
    ON tc.constraint_name = rc.constraint_name
    AND tc.table_schema = rc.constraint_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND ccu.table_name = 'competition_versions'
ORDER BY tc.table_name, tc.constraint_name;

-- 5. Test de suppression en cascade (ATTENTION: DESTRUCTIF)
-- Décommentez cette section SEULEMENT pour tester la suppression en cascade
-- ATTENTION: Cette opération est IRRÉVERSIBLE

/*
-- Créer une version de test
INSERT INTO competition_versions (id, name, year, is_active, max_adults, max_children, is_registration_open, jury_evaluation_enabled, success_average_adults, success_average_children)
VALUES ('test-version-id', 'Version Test', 2024, true, 10, 10, true, false, 70.0, 70.0);

-- Créer des données de test liées
INSERT INTO participants (id, full_name, age_group, competition_id, is_accepted)
VALUES ('test-participant-1', 'Participant Test 1', 'كبار', 'test-version-id', true);

INSERT INTO rounds (id, name, number, version_id)
VALUES ('test-round-1', 'Round Test 1', 1, 'test-version-id');

INSERT INTO round_jury_assignments (user_id, round_id)
VALUES ('test-jury-1', 'test-round-1');

INSERT INTO evaluations (id, participant_id, jury_id, round_id, total_score)
VALUES ('test-evaluation-1', 'test-participant-1', 'test-jury-1', 'test-round-1', 75.0);

INSERT INTO round_results (id, participant_id, round_id, version_id, score, passed)
VALUES ('test-result-1', 'test-participant-1', 'test-round-1', 'test-version-id', 75.0, true);

-- Vérifier que les données existent
SELECT 'competition_versions' as table_name, COUNT(*) as count FROM competition_versions WHERE id = 'test-version-id'
UNION ALL
SELECT 'participants', COUNT(*) FROM participants WHERE competition_id = 'test-version-id'
UNION ALL
SELECT 'rounds', COUNT(*) FROM rounds WHERE version_id = 'test-version-id'
UNION ALL
SELECT 'round_jury_assignments', COUNT(*) FROM round_jury_assignments WHERE round_id = 'test-round-1'
UNION ALL
SELECT 'evaluations', COUNT(*) FROM evaluations WHERE round_id = 'test-round-1'
UNION ALL
SELECT 'round_results', COUNT(*) FROM round_results WHERE version_id = 'test-version-id';

-- Supprimer la version de test (cela devrait supprimer TOUT en cascade)
DELETE FROM competition_versions WHERE id = 'test-version-id';

-- Vérifier que tout a été supprimé
SELECT 'competition_versions' as table_name, COUNT(*) as count FROM competition_versions WHERE id = 'test-version-id'
UNION ALL
SELECT 'participants', COUNT(*) FROM participants WHERE competition_id = 'test-version-id'
UNION ALL
SELECT 'rounds', COUNT(*) FROM rounds WHERE version_id = 'test-version-id'
UNION ALL
SELECT 'round_jury_assignments', COUNT(*) FROM round_jury_assignments WHERE round_id = 'test-round-1'
UNION ALL
SELECT 'evaluations', COUNT(*) FROM evaluations WHERE round_id = 'test-round-1'
UNION ALL
SELECT 'round_results', COUNT(*) FROM round_results WHERE version_id = 'test-version-id';
*/

-- 6. Fonction pour obtenir le nombre d'éléments liés avant suppression
CREATE OR REPLACE FUNCTION get_competition_related_counts(version_id_param TEXT)
RETURNS TABLE (
    table_name TEXT,
    count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'participants'::TEXT, COUNT(*)::BIGINT FROM participants WHERE competition_id = version_id_param
    UNION ALL
    SELECT 'rounds'::TEXT, COUNT(*)::BIGINT FROM rounds WHERE version_id = version_id_param
    UNION ALL
    SELECT 'evaluations'::TEXT, COUNT(*)::BIGINT FROM evaluations e JOIN rounds r ON e.round_id = r.id WHERE r.version_id = version_id_param
    UNION ALL
    SELECT 'round_jury_assignments'::TEXT, COUNT(*)::BIGINT FROM round_jury_assignments rja JOIN rounds r ON rja.round_id = r.id WHERE r.version_id = version_id_param
    UNION ALL
    SELECT 'round_results'::TEXT, COUNT(*)::BIGINT FROM round_results WHERE version_id = version_id_param;
END;
$$ LANGUAGE plpgsql;

-- 7. Exemple d'utilisation de la fonction
-- SELECT * FROM get_competition_related_counts('votre-version-id');
