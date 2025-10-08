-- Script pour supprimer les fonctions existantes avant de les recréer
-- Date: 2025-01-07

-- Supprimer toutes les fonctions existantes
DROP FUNCTION IF EXISTS get_users_with_profiles();
DROP FUNCTION IF EXISTS get_user_by_id(UUID);
DROP FUNCTION IF EXISTS search_users(TEXT);
DROP FUNCTION IF EXISTS get_users_by_role(TEXT);

-- Message de confirmation
DO $$
BEGIN
    RAISE NOTICE '✅ Fonctions supprimées avec succès !';
    RAISE NOTICE '📋 Fonctions supprimées:';
    RAISE NOTICE '  - get_users_with_profiles()';
    RAISE NOTICE '  - get_user_by_id(UUID)';
    RAISE NOTICE '  - search_users(TEXT)';
    RAISE NOTICE '  - get_users_by_role(TEXT)';
    RAISE NOTICE '';
    RAISE NOTICE '💡 Maintenant exécutez create_user_profiles_function.sql pour recréer les fonctions avec les bons types';
END $$;
