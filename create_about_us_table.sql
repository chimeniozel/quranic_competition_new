-- Table pour stocker les informations "من نحن" (À propos de nous)
CREATE TABLE IF NOT EXISTS about_us (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  image_url TEXT,
  whatsapp_url TEXT,
  email TEXT,
  address TEXT,
  website TEXT,
  facebook_url TEXT,
  instagram_url TEXT,
  youtube_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_about_us_created_at ON about_us(created_at DESC);

-- Trigger pour mettre à jour automatiquement updated_at
CREATE OR REPLACE FUNCTION update_about_us_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_about_us_updated_at_trigger
  BEFORE UPDATE ON about_us
  FOR EACH ROW
  EXECUTE FUNCTION update_about_us_updated_at();

-- Commentaires pour documentation
COMMENT ON TABLE about_us IS 'Table contenant les informations dynamiques de la page "من نحن" (À propos de nous)';
COMMENT ON COLUMN about_us.title IS 'Titre de la section À propos de nous';
COMMENT ON COLUMN about_us.content IS 'Contenu principal de la page (peut contenir du HTML ou du texte formaté)';
COMMENT ON COLUMN about_us.image_url IS 'URL de l\'image associée (optionnel)';
COMMENT ON COLUMN about_us.whatsapp_url IS 'Lien de la chaîne WhatsApp';
COMMENT ON COLUMN about_us.email IS 'Adresse email de contact';
COMMENT ON COLUMN about_us.address IS 'Adresse physique';
COMMENT ON COLUMN about_us.website IS 'Site web (optionnel)';
COMMENT ON COLUMN about_us.facebook_url IS 'Lien Facebook (optionnel)';
COMMENT ON COLUMN about_us.instagram_url IS 'Lien Instagram (optionnel)';
COMMENT ON COLUMN about_us.youtube_url IS 'Lien de la chaîne YouTube (optionnel)';

