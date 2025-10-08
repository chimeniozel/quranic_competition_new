-- Test du système de gestion des utilisateurs
-- Date: 2025-01-07

-- Test 1: Vérifier que la table profiles existe et contient des données
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles') THEN
        RAISE NOTICE '✅ Table profiles existe';
        
        DECLARE
            profile_count INTEGER;
            rec RECORD;
        BEGIN
            SELECT COUNT(*) INTO profile_count FROM public.profiles;
            RAISE NOTICE '📊 Nombre de profils: %', profile_count;
            
            IF profile_count > 0 THEN
                RAISE NOTICE '📋 Rôles trouvés:';
                FOR rec IN 
                    SELECT role, COUNT(*) as count 
                    FROM public.profiles 
                    GROUP BY role 
                    ORDER BY count DESC
                LOOP
                    RAISE NOTICE '  - %: % utilisateur(s)', rec.role, rec.count;
                END LOOP;
            END IF;
        END;
    ELSE
        RAISE NOTICE '❌ Table profiles n''existe pas';
    END IF;
END $$;

-- Test 2: Vérifier que les fonctions SQL existent
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔍 Vérification des fonctions SQL:';
    
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_users_with_profiles') THEN
        RAISE NOTICE '✅ get_users_with_profiles() existe';
    ELSE
        RAISE NOTICE '❌ get_users_with_profiles() manquante';
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_user_by_id') THEN
        RAISE NOTICE '✅ get_user_by_id() existe';
    ELSE
        RAISE NOTICE '❌ get_user_by_id() manquante';
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'search_users') THEN
        RAISE NOTICE '✅ search_users() existe';
    ELSE
        RAISE NOTICE '❌ search_users() manquante';
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_users_by_role') THEN
        RAISE NOTICE '✅ get_users_by_role() existe';
    ELSE
        RAISE NOTICE '❌ get_users_by_role() manquante';
    END IF;
END $$;

-- Test 3: Tester la fonction get_users_with_profiles
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_users_with_profiles') THEN
        RAISE NOTICE '';
        RAISE NOTICE '🧪 Test de get_users_with_profiles():';
        
        DECLARE
            rec RECORD;
            count INTEGER := 0;
        BEGIN
            FOR rec IN SELECT * FROM get_users_with_profiles() LIMIT 3
            LOOP
                count := count + 1;
                RAISE NOTICE '  - % | % | % | %', rec.id, rec.email, rec.role, rec.full_name;
            END LOOP;
            
            IF count = 0 THEN
                RAISE NOTICE '  ℹ️ Aucun utilisateur trouvé';
            END IF;
        END;
    END IF;
END $$;

-- Test 4: Tester la fonction get_users_by_role avec jury
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_users_by_role') THEN
        RAISE NOTICE '';
        RAISE NOTICE '🧪 Test de get_users_by_role(''jury''):';
        
        DECLARE
            rec RECORD;
            count INTEGER := 0;
        BEGIN
            FOR rec IN SELECT * FROM get_users_by_role('jury')
            LOOP
                count := count + 1;
                RAISE NOTICE '  - % | % | %', rec.id, rec.email, rec.full_name;
            END LOOP;
            
            IF count = 0 THEN
                RAISE NOTICE '  ℹ️ Aucun utilisateur avec le rôle jury';
            ELSE
                RAISE NOTICE '  📊 % utilisateur(s) avec le rôle jury', count;
            END IF;
        END;
    END IF;
END $$;

-- Recommandations
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '💡 Recommandations:';
    RAISE NOTICE '1. Si les fonctions manquent, exécutez:';
    RAISE NOTICE '   - drop_user_profiles_functions.sql';
    RAISE NOTICE '   - create_user_profiles_function.sql';
    RAISE NOTICE '2. Si la table profiles est vide, exécutez:';
    RAISE NOTICE '   - migrate_existing_users_simple.sql';
    RAISE NOTICE '3. Si vous voulez créer un utilisateur jury de test:';
    RAISE NOTICE '   - Inscrivez-vous avec un nouveau compte';
    RAISE NOTICE '   - Modifiez le rôle dans la base de données:';
    RAISE NOTICE '   UPDATE public.profiles SET role = ''jury'' WHERE email = ''votre_email'';';
END $$;
