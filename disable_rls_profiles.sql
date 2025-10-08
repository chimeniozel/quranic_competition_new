-- Script pour désactiver RLS sur la table profiles
-- Date: 2025-01-07
-- ATTENTION: Désactiver RLS supprime toutes les restrictions de sécurité

-- Désactiver RLS
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- Supprimer toutes les politiques RLS existantes
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Super admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Super admins can update all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Super admins can insert profiles" ON public.profiles;

-- Message de confirmation
DO $$
BEGIN
    RAISE NOTICE '⚠️ RLS désactivé sur la table profiles';
    RAISE NOTICE '🔓 Toutes les politiques de sécurité ont été supprimées';
    RAISE NOTICE '⚠️ ATTENTION: Tous les utilisateurs peuvent maintenant accéder à tous les profils';
END $$;
