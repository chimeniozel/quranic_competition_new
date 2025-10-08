-- Fonction pour récupérer les utilisateurs avec leurs profils
-- Date: 2025-01-07

-- Créer une fonction qui retourne les utilisateurs avec leurs profils
CREATE OR REPLACE FUNCTION get_users_with_profiles()
RETURNS TABLE (
    id UUID,
    email VARCHAR(255),
    role TEXT,
    full_name TEXT,
    phone TEXT,
    is_validated BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        u.email,
        p.role,
        p.full_name,
        p.phone,
        p.is_validated,
        p.created_at,
        p.updated_at
    FROM public.profiles p
    JOIN auth.users u ON p.id = u.id
    ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour récupérer un utilisateur spécifique par ID
CREATE OR REPLACE FUNCTION get_user_by_id(user_id UUID)
RETURNS TABLE (
    id UUID,
    email VARCHAR(255),
    role TEXT,
    full_name TEXT,
    phone TEXT,
    is_validated BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        u.email,
        p.role,
        p.full_name,
        p.phone,
        p.is_validated,
        p.created_at,
        p.updated_at
    FROM public.profiles p
    JOIN auth.users u ON p.id = u.id
    WHERE p.id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour rechercher des utilisateurs
CREATE OR REPLACE FUNCTION search_users(search_query TEXT)
RETURNS TABLE (
    id UUID,
    email VARCHAR(255),
    role TEXT,
    full_name TEXT,
    phone TEXT,
    is_validated BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        u.email,
        p.role,
        p.full_name,
        p.phone,
        p.is_validated,
        p.created_at,
        p.updated_at
    FROM public.profiles p
    JOIN auth.users u ON p.id = u.id
    WHERE p.full_name ILIKE '%' || search_query || '%'
    ORDER BY p.full_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour récupérer les utilisateurs par rôle
CREATE OR REPLACE FUNCTION get_users_by_role(user_role TEXT)
RETURNS TABLE (
    id UUID,
    email VARCHAR(255),
    role TEXT,
    full_name TEXT,
    phone TEXT,
    is_validated BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        u.email,
        p.role,
        p.full_name,
        p.phone,
        p.is_validated,
        p.created_at,
        p.updated_at
    FROM public.profiles p
    JOIN auth.users u ON p.id = u.id
    WHERE p.role = user_role
    ORDER BY p.full_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Message de confirmation
DO $$
BEGIN
    RAISE NOTICE '✅ Fonctions SQL créées avec succès !';
    RAISE NOTICE '📋 Fonctions disponibles:';
    RAISE NOTICE '  - get_users_with_profiles()';
    RAISE NOTICE '  - get_user_by_id(user_id UUID)';
    RAISE NOTICE '  - search_users(search_query TEXT)';
    RAISE NOTICE '  - get_users_by_role(user_role TEXT)';
END $$;
