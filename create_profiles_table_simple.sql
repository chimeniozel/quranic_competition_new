-- Migration simple pour créer la table profiles sans vue complexe
-- Date: 2025-01-07
-- Description: Crée une table profiles basique sans vue user_profiles_view

-- Supprimer complètement l'ancienne table profiles si elle existe
DROP TABLE IF EXISTS public.profiles CASCADE;

-- Créer une nouvelle table "profiles" simple
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT DEFAULT 'membre' CHECK (role IN ('super_admin', 'admin', 'jury', 'membre')),
    full_name TEXT,
    phone TEXT,
    is_validated BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Index simples
CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_profiles_validated ON public.profiles(is_validated);

-- Activer RLS (optionnel - peut être désactivé si nécessaire)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Politiques RLS basiques
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- Fonction simple pour nouveaux utilisateurs
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, phone)
    VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'phone');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour nouveaux utilisateurs
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();

-- Fonction pour updated_at (si elle n'existe pas déjà)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_updated_at_column') THEN
        CREATE FUNCTION public.update_updated_at_column()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
    END IF;
END $$;

-- Trigger pour updated_at
CREATE TRIGGER update_profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Fonctions de permissions simples
CREATE OR REPLACE FUNCTION public.user_has_permission(user_id UUID, permission TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT role INTO user_role FROM public.profiles WHERE id = user_id;
    
    CASE permission
        WHEN 'can_delete' THEN
            RETURN user_role = 'super_admin';
        WHEN 'can_modify' THEN
            RETURN user_role IN ('super_admin', 'admin');
        WHEN 'can_create_versions' THEN
            RETURN user_role = 'super_admin';
        WHEN 'can_assign_roles' THEN
            RETURN user_role = 'super_admin';
        WHEN 'can_publish_content' THEN
            RETURN user_role IN ('super_admin', 'admin');
        WHEN 'can_view_admin' THEN
            RETURN user_role IN ('super_admin', 'admin', 'jury', 'membre');
        WHEN 'can_evaluate' THEN
            RETURN user_role IN ('super_admin', 'admin', 'jury');
        ELSE
            RETURN FALSE;
    END CASE;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour obtenir les permissions d'un utilisateur
CREATE OR REPLACE FUNCTION public.get_user_permissions(user_id UUID)
RETURNS JSON AS $$
DECLARE
    user_role TEXT;
    permissions JSON;
BEGIN
    SELECT role INTO user_role FROM public.profiles WHERE id = user_id;
    
    permissions := json_build_object(
        'can_delete', user_role = 'super_admin',
        'can_modify', user_role IN ('super_admin', 'admin'),
        'can_create_versions', user_role = 'super_admin',
        'can_assign_roles', user_role = 'super_admin',
        'can_publish_content', user_role IN ('super_admin', 'admin'),
        'can_view_admin', user_role IN ('super_admin', 'admin', 'jury', 'membre'),
        'can_evaluate', user_role IN ('super_admin', 'admin', 'jury')
    );
    
    RETURN permissions;
END;
$$ LANGUAGE plpgsql;

-- Message de confirmation
DO $$
BEGIN
    RAISE NOTICE '✅ Table profiles créée avec succès !';
    RAISE NOTICE '📊 Structure:';
    RAISE NOTICE '  - Table: public.profiles';
    RAISE NOTICE '  - Rôles: super_admin, admin, membre';
    RAISE NOTICE '  - RLS: Activé (peut être désactivé si nécessaire)';
    RAISE NOTICE '  - Triggers: handle_new_user, update_updated_at';
    RAISE NOTICE '  - Fonctions: user_has_permission, get_user_permissions';
END $$;
