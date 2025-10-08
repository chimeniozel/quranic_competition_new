-- Test simple du système de rôles
-- Date: 2025-01-07

-- Test 1: Vérifier que la table existe
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles') THEN
        RAISE NOTICE '✅ Table profiles existe';
    ELSE
        RAISE NOTICE '❌ Table profiles manquante';
    END IF;
END $$;

-- Test 2: Vérifier les colonnes
DO $$
BEGIN
    RAISE NOTICE '📋 Colonnes de la table profiles:';
    FOR rec IN 
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        ORDER BY ordinal_position
    LOOP
        RAISE NOTICE '  - %: % (nullable: %, default: %)', 
            rec.column_name, rec.data_type, rec.is_nullable, rec.column_default;
    END LOOP;
END $$;

-- Test 3: Vérifier les index
DO $$
BEGIN
    RAISE NOTICE '📊 Index sur la table profiles:';
    FOR rec IN 
        SELECT indexname, indexdef 
        FROM pg_indexes 
        WHERE tablename = 'profiles'
    LOOP
        RAISE NOTICE '  - %', rec.indexname;
    END LOOP;
END $$;

-- Test 4: Vérifier les triggers
DO $$
BEGIN
    RAISE NOTICE '🔧 Triggers sur la table profiles:';
    FOR rec IN 
        SELECT tgname as trigger_name, tgenabled as enabled
        FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname = 'profiles'
        AND t.tgname NOT LIKE 'RI_%'
    LOOP
        RAISE NOTICE '  - % (activé: %)', rec.trigger_name, rec.enabled;
    END LOOP;
END $$;

-- Test 5: Vérifier les fonctions
DO $$
BEGIN
    RAISE NOTICE '⚙️ Fonctions créées:';
    
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'handle_new_user') THEN
        RAISE NOTICE '  ✅ handle_new_user';
    ELSE
        RAISE NOTICE '  ❌ handle_new_user manquante';
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'user_has_permission') THEN
        RAISE NOTICE '  ✅ user_has_permission';
    ELSE
        RAISE NOTICE '  ❌ user_has_permission manquante';
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_user_permissions') THEN
        RAISE NOTICE '  ✅ get_user_permissions';
    ELSE
        RAISE NOTICE '  ❌ get_user_permissions manquante';
    END IF;
END $$;

-- Test 6: Vérifier RLS
DO $$
DECLARE
    rls_enabled BOOLEAN;
    policy_count INTEGER;
BEGIN
    SELECT relrowsecurity INTO rls_enabled 
    FROM pg_class 
    WHERE relname = 'profiles';
    
    IF rls_enabled THEN
        RAISE NOTICE '🔒 RLS activé sur profiles';
        
        SELECT COUNT(*) INTO policy_count 
        FROM pg_policies 
        WHERE tablename = 'profiles';
        
        RAISE NOTICE '📋 Nombre de politiques: %', policy_count;
        
        FOR rec IN 
            SELECT policyname, permissive, roles, cmd, qual
            FROM pg_policies 
            WHERE tablename = 'profiles'
        LOOP
            RAISE NOTICE '  - % (%): %', rec.policyname, rec.cmd, rec.qual;
        END LOOP;
    ELSE
        RAISE NOTICE '🔓 RLS désactivé sur profiles';
    END IF;
END $$;

-- Test 7: Compter les utilisateurs existants
DO $$
DECLARE
    user_count INTEGER;
    profile_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM auth.users;
    SELECT COUNT(*) INTO profile_count FROM public.profiles;
    
    RAISE NOTICE '📊 Statistiques:';
    RAISE NOTICE '  - Utilisateurs dans auth.users: %', user_count;
    RAISE NOTICE '  - Profils dans public.profiles: %', profile_count;
    
    IF profile_count > 0 THEN
        RAISE NOTICE '📋 Répartition par rôle:';
        FOR rec IN 
            SELECT role, COUNT(*) as count 
            FROM public.profiles 
            GROUP BY role 
            ORDER BY count DESC
        LOOP
            RAISE NOTICE '  - %: % utilisateur(s)', rec.role, rec.count;
        END LOOP;
    END IF;
END $$;
