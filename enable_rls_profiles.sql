-- Script pour réactiver RLS sur la table profiles
-- Date: 2025-01-07

-- Réactiver RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Créer les politiques RLS basiques
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- Politiques pour Super Admins (optionnel)
CREATE POLICY "Super admins can view all profiles" ON public.profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.profiles p 
            WHERE p.id = auth.uid() AND p.role = 'super_admin'
        )
    );

CREATE POLICY "Super admins can update all profiles" ON public.profiles
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.profiles p 
            WHERE p.id = auth.uid() AND p.role = 'super_admin'
        )
    );

-- Message de confirmation
DO $$
BEGIN
    RAISE NOTICE '✅ RLS réactivé sur la table profiles';
    RAISE NOTICE '🔒 Politiques de sécurité restaurées';
    RAISE NOTICE '👤 Utilisateurs: peuvent voir/modifier leur propre profil';
    RAISE NOTICE '👑 Super Admins: peuvent voir/modifier tous les profils';
END $$;
