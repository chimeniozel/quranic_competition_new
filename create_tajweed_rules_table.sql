-- Création de la table tajweed_rules pour les règles de Tajweed
CREATE TABLE IF NOT EXISTS tajweed_rules (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('post', 'video')),
    video_url TEXT,
    image_url TEXT,
    author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    author_name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT FALSE -- Les nouvelles règles sont non actives par défaut
);

-- Créer un index sur le type pour améliorer les performances de filtrage
CREATE INDEX IF NOT EXISTS idx_tajweed_rules_type ON tajweed_rules(type);

-- Créer un index sur is_active pour améliorer les performances de filtrage
CREATE INDEX IF NOT EXISTS idx_tajweed_rules_is_active ON tajweed_rules(is_active);

-- Créer un index sur created_at pour améliorer les performances de tri
CREATE INDEX IF NOT EXISTS idx_tajweed_rules_created_at ON tajweed_rules(created_at);

-- Créer un index composite pour les requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_tajweed_rules_active_type ON tajweed_rules(is_active, type);

-- Créer un index sur author_id pour les requêtes par auteur
CREATE INDEX IF NOT EXISTS idx_tajweed_rules_author_id ON tajweed_rules(author_id);

-- Fonction pour mettre à jour automatiquement updated_at
CREATE OR REPLACE FUNCTION update_tajweed_rules_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour mettre à jour automatiquement updated_at
CREATE TRIGGER trigger_update_tajweed_rules_updated_at
    BEFORE UPDATE ON tajweed_rules
    FOR EACH ROW
    EXECUTE FUNCTION update_tajweed_rules_updated_at();

-- RLS (Row Level Security) - Politique pour permettre la lecture à tous les utilisateurs authentifiés
ALTER TABLE tajweed_rules ENABLE ROW LEVEL SECURITY;

-- Politique pour permettre la lecture des règles actives à tous les utilisateurs
CREATE POLICY "Allow read access to active rules for authenticated users"
    ON tajweed_rules FOR SELECT
    TO authenticated
    USING (is_active = true);

-- Politique pour permettre la lecture de toutes les règles aux admins et super admins
CREATE POLICY "Allow read access to all rules for admins"
    ON tajweed_rules FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM app_users 
            WHERE app_users.id = auth.uid() 
            AND app_users.role IN ('admin', 'super_admin')
        )
    );

-- Politique pour permettre l'insertion aux admins et super admins
CREATE POLICY "Allow insert for admins and super admins"
    ON tajweed_rules FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM app_users 
            WHERE app_users.id = auth.uid() 
            AND app_users.role IN ('admin', 'super_admin')
        )
    );

-- Politique pour permettre la mise à jour aux admins et super admins
CREATE POLICY "Allow update for admins and super admins"
    ON tajweed_rules FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM app_users 
            WHERE app_users.id = auth.uid() 
            AND app_users.role IN ('admin', 'super_admin')
        )
    );

-- Politique pour permettre la suppression aux admins et super admins
CREATE POLICY "Allow delete for admins and super admins"
    ON tajweed_rules FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM app_users 
            WHERE app_users.id = auth.uid() 
            AND app_users.role IN ('admin', 'super_admin')
        )
    );

-- Commentaires sur la table et les colonnes
COMMENT ON TABLE tajweed_rules IS 'Table pour stocker les règles de Tajweed (posts et vidéos)';
COMMENT ON COLUMN tajweed_rules.id IS 'Identifiant unique de la règle';
COMMENT ON COLUMN tajweed_rules.title IS 'Titre de la règle de Tajweed';
COMMENT ON COLUMN tajweed_rules.content IS 'Contenu détaillé de la règle';
COMMENT ON COLUMN tajweed_rules.type IS 'Type de contenu: post ou video';
COMMENT ON COLUMN tajweed_rules.video_url IS 'URL de la vidéo (si type = video)';
COMMENT ON COLUMN tajweed_rules.image_url IS 'URL de l''image associée';
COMMENT ON COLUMN tajweed_rules.author_id IS 'ID de l''auteur de la règle';
COMMENT ON COLUMN tajweed_rules.author_name IS 'Nom de l''auteur de la règle';
COMMENT ON COLUMN tajweed_rules.created_at IS 'Date de création de la règle';
COMMENT ON COLUMN tajweed_rules.updated_at IS 'Date de dernière modification';
COMMENT ON COLUMN tajweed_rules.is_active IS 'Indique si la règle est active et visible par les participants';

-- Insérer quelques exemples de règles de Tajweed (optionnel)
-- INSERT INTO tajweed_rules (title, content, type, author_id, author_name, is_active) VALUES
-- ('قاعدة النون الساكنة والتنوين', 'عندما تأتي النون الساكنة أو التنوين قبل حرف من حروف الإدغام...', 'post', '00000000-0000-0000-0000-000000000000', 'الإدارة', true),
-- ('قاعدة الميم الساكنة', 'عندما تأتي الميم الساكنة قبل حرف الباء...', 'post', '00000000-0000-0000-0000-000000000000', 'الإدارة', true),
-- ('درس في أحكام المد', 'https://youtube.com/watch?v=example1', 'video', '00000000-0000-0000-0000-000000000000', 'الإدارة', true);
