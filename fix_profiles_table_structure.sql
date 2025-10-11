-- Script pour corriger et standardiser la table profiles
-- Assure que la table profiles a toutes les colonnes nécessaires

-- 1. Vérifier et ajouter les colonnes manquantes si nécessaire
DO $$ 
BEGIN
    -- Ajouter la colonne phone si elle n'existe pas
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'phone'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN phone TEXT;
    END IF;

    -- Ajouter la colonne full_name si elle n'existe pas
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'full_name'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN full_name TEXT;
    END IF;

    -- Ajouter la colonne is_validated si elle n'existe pas
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'is_validated'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN is_validated BOOLEAN DEFAULT FALSE;
    END IF;

    -- Ajouter la colonne role si elle n'existe pas
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'role'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN role TEXT DEFAULT 'membre';
    END IF;

    -- Ajouter la colonne created_at si elle n'existe pas
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'created_at'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN created_at TIMESTAMP DEFAULT NOW();
    END IF;

    -- Ajouter la colonne updated_at si elle n'existe pas
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN updated_at TIMESTAMP DEFAULT NOW();
    END IF;
END $$;

-- 2. Mettre à jour les contraintes
-- Supprimer l'ancienne contrainte si elle existe
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;

-- Ajouter la nouvelle contrainte avec tous les rôles
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check 
CHECK (role IN ('super_admin', 'admin', 'jury', 'membre'));

-- 3. Créer les index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_is_validated ON public.profiles(is_validated);
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON public.profiles(created_at);

-- 4. Mettre à jour le trigger pour updated_at si nécessaire
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Supprimer l'ancien trigger s'il existe
DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;

-- Créer le nouveau trigger
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 5. Mettre à jour les politiques RLS si nécessaire
-- Supprimer les anciennes politiques
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Super admins can view all profiles" ON public.profiles;

-- Créer les nouvelles politiques
CREATE POLICY "Users can view own profile" ON public.profiles 
FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Super admins can view all profiles" ON public.profiles 
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role = 'super_admin'
    )
);

CREATE POLICY "Admins can view all profiles" ON public.profiles 
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.profiles p 
        WHERE p.id = auth.uid() AND p.role IN ('super_admin', 'admin')
    )
);

-- 6. Mettre à jour les données existantes si nécessaire
-- Synchroniser les données des utilisateurs existants
UPDATE public.profiles 
SET 
    is_validated = COALESCE(is_validated, FALSE),
    role = COALESCE(role, 'membre'),
    full_name = COALESCE(full_name, ''),
    phone = COALESCE(phone, ''),
    updated_at = NOW()
WHERE id IN (
    SELECT id FROM auth.users 
    WHERE id NOT IN (SELECT id FROM public.profiles)
);

-- 7. Message de confirmation
DO $$ 
BEGIN
    RAISE NOTICE '✅ Table profiles standardisée avec succès !';
    RAISE NOTICE '📊 Colonnes disponibles: id, full_name, phone, role, is_validated, created_at, updated_at';
    RAISE NOTICE '🔐 Rôles supportés: super_admin, admin, jury, membre';
    RAISE NOTICE '🛡️ Politiques RLS activées pour la sécurité';
END $$;
