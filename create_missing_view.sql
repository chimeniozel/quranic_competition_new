-- Script minimal pour créer la vue manquante jury_round_assignments_view

-- Créer la vue pour faciliter les requêtes
CREATE OR REPLACE VIEW jury_round_assignments_view AS
SELECT 
    rja.id as assignment_id,
    rja.user_id as jury_id,
    rja.round_id,
    p.full_name as jury_name,
    p.phone as jury_phone,
    p.email as jury_email,
    p.role,
    r.number as round_number,
    r.name as round_name,
    r.version_id,
    cv.name as version_name,
    cv.year as version_year,
    rja.created_at as assigned_at
FROM round_jury_assignments rja
JOIN profiles p ON rja.user_id = p.id
JOIN rounds r ON rja.round_id = r.id
JOIN competition_versions cv ON r.version_id = cv.id
WHERE p.role = 'jury';

-- Vérifier que la vue a été créée
SELECT 'Vue jury_round_assignments_view créée avec succès' as status;
