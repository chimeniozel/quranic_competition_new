-- Script SQL pour créer la table quranic_benefits
-- Exécuter ce script dans Supabase SQL Editor

CREATE TABLE IF NOT EXISTS quranic_benefits (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    image_url TEXT,
    author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    author_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT FALSE -- Les nouvelles bénéfices sont non actives par défaut
);

-- Index pour améliorer les performances de recherche
CREATE INDEX IF NOT EXISTS idx_quranic_benefits_title ON quranic_benefits(title);
CREATE INDEX IF NOT EXISTS idx_quranic_benefits_content ON quranic_benefits USING gin(to_tsvector('arabic', content));
CREATE INDEX IF NOT EXISTS idx_quranic_benefits_author_id ON quranic_benefits(author_id);
CREATE INDEX IF NOT EXISTS idx_quranic_benefits_created_at ON quranic_benefits(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_quranic_benefits_is_active ON quranic_benefits(is_active);

-- RLS (Row Level Security) policies
ALTER TABLE quranic_benefits ENABLE ROW LEVEL SECURITY;

-- Politique pour permettre à tous les utilisateurs authentifiés de lire les bénéfices actifs
CREATE POLICY "Allow authenticated users to read active benefits" ON quranic_benefits
    FOR SELECT USING (auth.role() = 'authenticated' AND is_active = true);

-- Politique pour permettre aux administrateurs de lire tous les bénéfices
CREATE POLICY "Allow admins to read all benefits" ON quranic_benefits
    FOR SELECT USING (
        auth.role() = 'authenticated' AND 
        EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = auth.uid() 
            AND (auth.users.raw_user_meta_data->>'role' = 'admin' OR auth.users.raw_user_meta_data->>'role' = 'super_admin')
        )
    );

-- Politique pour permettre aux administrateurs de créer des bénéfices
CREATE POLICY "Allow admins to create benefits" ON quranic_benefits
    FOR INSERT WITH CHECK (
        auth.role() = 'authenticated' AND 
        auth.uid() = author_id AND
        EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = auth.uid() 
            AND (auth.users.raw_user_meta_data->>'role' = 'admin' OR auth.users.raw_user_meta_data->>'role' = 'super_admin')
        )
    );

-- Politique pour permettre aux administrateurs de modifier les bénéfices
CREATE POLICY "Allow admins to update benefits" ON quranic_benefits
    FOR UPDATE USING (
        auth.role() = 'authenticated' AND 
        EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = auth.uid() 
            AND (auth.users.raw_user_meta_data->>'role' = 'admin' OR auth.users.raw_user_meta_data->>'role' = 'super_admin')
        )
    );

-- Politique pour permettre aux administrateurs de supprimer les bénéfices (soft delete)
CREATE POLICY "Allow admins to delete benefits" ON quranic_benefits
    FOR UPDATE USING (
        auth.role() = 'authenticated' AND 
        EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = auth.uid() 
            AND (auth.users.raw_user_meta_data->>'role' = 'admin' OR auth.users.raw_user_meta_data->>'role' = 'super_admin')
        )
    );

-- Fonction pour mettre à jour automatiquement updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger pour mettre à jour automatiquement updated_at
CREATE TRIGGER update_quranic_benefits_updated_at 
    BEFORE UPDATE ON quranic_benefits 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Commentaires sur la table et les colonnes
COMMENT ON TABLE quranic_benefits IS 'Table pour stocker les bénéfices coraniques ajoutés par les administrateurs';
COMMENT ON COLUMN quranic_benefits.id IS 'Identifiant unique de la faveur coranique';
COMMENT ON COLUMN quranic_benefits.title IS 'Titre de la faveur coranique';
COMMENT ON COLUMN quranic_benefits.content IS 'Contenu détaillé de la faveur coranique';
COMMENT ON COLUMN quranic_benefits.image_url IS 'URL de l\'image associée (optionnelle)';
COMMENT ON COLUMN quranic_benefits.author_id IS 'ID de l\'utilisateur qui a créé la faveur';
COMMENT ON COLUMN quranic_benefits.author_name IS 'Nom de l\'auteur de la faveur';
COMMENT ON COLUMN quranic_benefits.created_at IS 'Date et heure de création';
COMMENT ON COLUMN quranic_benefits.updated_at IS 'Date et heure de dernière modification';
COMMENT ON COLUMN quranic_benefits.is_active IS 'Indique si la faveur est active/visible';
