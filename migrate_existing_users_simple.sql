-- Migration des utilisateurs existants vers la nouvelle table profiles
-- Date: 2025-01-07

-- Migrer les utilisateurs existants vers la table profiles
INSERT INTO public.profiles (id, role, full_name, phone, is_validated, created_at, updated_at)
SELECT 
    u.id,
    CASE 
        -- Mapping des anciens rôles vers les nouveaux
        WHEN COALESCE(u.raw_user_meta_data->>'role', '') = 'super_admin' THEN 'super_admin'
        WHEN COALESCE(u.raw_user_meta_data->>'role', '') = 'admin' THEN 'admin'
        WHEN COALESCE(u.raw_user_meta_data->>'role', '') = 'jury' THEN 'jury'
        WHEN COALESCE(u.raw_user_meta_data->>'role', '') = 'participant' THEN 'membre'
        WHEN COALESCE(u.raw_user_meta_data->>'role', '') = 'user' THEN 'membre'
        ELSE 'membre' -- Rôle par défaut
    END as role,
    u.raw_user_meta_data->>'full_name' as full_name,
    u.raw_user_meta_data->>'phone' as phone,
    COALESCE((u.raw_user_meta_data->>'is_validated')::boolean, false) as is_validated,
    u.created_at,
    NOW() as updated_at
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = u.id
);

-- Afficher les statistiques de migration
DO $$
DECLARE
    migrated_count INTEGER;
    total_users INTEGER;
    super_admin_count INTEGER;
    admin_count INTEGER;
    jury_count INTEGER;
    membre_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO migrated_count FROM public.profiles;
    SELECT COUNT(*) INTO total_users FROM auth.users;
    SELECT COUNT(*) INTO super_admin_count FROM public.profiles WHERE role = 'super_admin';
    SELECT COUNT(*) INTO admin_count FROM public.profiles WHERE role = 'admin';
    SELECT COUNT(*) INTO jury_count FROM public.profiles WHERE role = 'jury';
    SELECT COUNT(*) INTO membre_count FROM public.profiles WHERE role = 'membre';
    
    RAISE NOTICE '✅ Migration terminée !';
    RAISE NOTICE '📊 Statistiques:';
    RAISE NOTICE '  - Utilisateurs totaux dans auth.users: %', total_users;
    RAISE NOTICE '  - Profils créés dans profiles: %', migrated_count;
    RAISE NOTICE '  - Super Admins: %', super_admin_count;
    RAISE NOTICE '  - Admins: %', admin_count;
    RAISE NOTICE '  - Jury: %', jury_count;
    RAISE NOTICE '  - Membres: %', membre_count;
    
    IF migrated_count = total_users THEN
        RAISE NOTICE '✅ Tous les utilisateurs ont été migrés avec succès';
    ELSE
        RAISE NOTICE '⚠️ Certains utilisateurs n''ont pas été migrés';
    END IF;
END $$;
