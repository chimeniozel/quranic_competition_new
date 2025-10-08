-- Test rapide pour vérifier que la table profiles fonctionne
-- Date: 2025-01-07

-- Test 1: Vérifier l'existence de la table
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles') THEN
        RAISE NOTICE '✅ Table profiles existe';
    ELSE
        RAISE NOTICE '❌ Table profiles manquante - Exécutez create_profiles_table_simple.sql';
    END IF;
END $$;

-- Test 2: Compter les profils existants
DO $$
DECLARE
    profile_count INTEGER;
    user_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO profile_count FROM public.profiles;
    SELECT COUNT(*) INTO user_count FROM auth.users;
    
    RAISE NOTICE '📊 Statistiques:';
    RAISE NOTICE '  - Utilisateurs dans auth.users: %', user_count;
    RAISE NOTICE '  - Profils dans public.profiles: %', profile_count;
    
    IF profile_count = 0 AND user_count > 0 THEN
        RAISE NOTICE '⚠️ Aucun profil trouvé - Exécutez migrate_existing_users_simple.sql';
    ELSIF profile_count < user_count THEN
        RAISE NOTICE '⚠️ Certains utilisateurs n''ont pas de profil';
    ELSIF profile_count > 0 THEN
        RAISE NOTICE '✅ Profils trouvés - Le système devrait fonctionner';
    END IF;
END $$;

-- Test 3: Afficher un échantillon des profils
DO $$
DECLARE
    rec RECORD;
BEGIN
    IF EXISTS (SELECT 1 FROM public.profiles LIMIT 1) THEN
        RAISE NOTICE '📋 Échantillon des profils:';
        FOR rec IN 
            SELECT p.id, p.role, p.full_name, u.email
            FROM public.profiles p
            JOIN auth.users u ON p.id = u.id
            LIMIT 3
        LOOP
            RAISE NOTICE '  - % | % | % | %', rec.id, rec.role, rec.full_name, rec.email;
        END LOOP;
    ELSE
        RAISE NOTICE 'ℹ️ Aucun profil à afficher';
    END IF;
END $$;

-- Test 4: Vérifier les rôles
DO $$
BEGIN
    RAISE NOTICE '🎭 Rôles trouvés:';
    FOR rec IN 
        SELECT role, COUNT(*) as count 
        FROM public.profiles 
        GROUP BY role 
        ORDER BY count DESC
    LOOP
        RAISE NOTICE '  - %: % utilisateur(s)', rec.role, rec.count;
    END LOOP;
END $$;
