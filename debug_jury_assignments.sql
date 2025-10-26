-- Script de débogage pour vérifier les assignations de jurys

-- 1. Vérifier la structure de la table round_jury_assignments
SELECT 
    'Structure de round_jury_assignments' as info,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'round_jury_assignments'
ORDER BY ordinal_position;

-- 2. Vérifier les données dans round_jury_assignments
SELECT 
    'Données dans round_jury_assignments' as info,
    user_id,
    round_id,
    created_at
FROM round_jury_assignments
ORDER BY created_at DESC;

-- 3. Vérifier les rounds et leurs versions
SELECT 
    'Rounds et versions' as info,
    r.id as round_id,
    r.number as round_number,
    r.version_id,
    cv.name as version_name,
    cv.year as version_year
FROM rounds r
JOIN competition_versions cv ON r.version_id = cv.id
ORDER BY cv.year DESC, r.number;

-- 4. Vérifier les jurys (profiles avec role = 'jury')
SELECT 
    'Jurys disponibles' as info,
    id,
    full_name,
    email,
    role
FROM profiles 
WHERE role = 'jury'
ORDER BY full_name;

-- 5. Vérifier les assignations complètes (jury -> round -> version)
SELECT 
    'Assignations complètes' as info,
    p.full_name as jury_name,
    r.number as round_number,
    cv.name as version_name,
    cv.year as version_year,
    rja.created_at as assigned_at
FROM round_jury_assignments rja
JOIN profiles p ON rja.user_id = p.id
JOIN rounds r ON rja.round_id = r.id
JOIN competition_versions cv ON r.version_id = cv.id
WHERE p.role = 'jury'
ORDER BY cv.year DESC, r.number, p.full_name;
