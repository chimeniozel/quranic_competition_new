-- Script pour ajouter les colonnes de coordonnées à la table about_us
-- À exécuter si la table about_us existe déjà

ALTER TABLE about_us
ADD COLUMN IF NOT EXISTS whatsapp_url TEXT,
ADD COLUMN IF NOT EXISTS email TEXT,
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS website TEXT,
ADD COLUMN IF NOT EXISTS facebook_url TEXT,
ADD COLUMN IF NOT EXISTS instagram_url TEXT,
ADD COLUMN IF NOT EXISTS youtube_url TEXT;

-- Commentaires pour documentation
COMMENT ON COLUMN about_us.whatsapp_url IS 'Lien de la chaîne WhatsApp';
COMMENT ON COLUMN about_us.email IS 'Adresse email de contact';
COMMENT ON COLUMN about_us.address IS 'Adresse physique';
COMMENT ON COLUMN about_us.website IS 'Site web (optionnel)';
COMMENT ON COLUMN about_us.facebook_url IS 'Lien Facebook (optionnel)';
COMMENT ON COLUMN about_us.instagram_url IS 'Lien Instagram (optionnel)';
COMMENT ON COLUMN about_us.youtube_url IS 'Lien de la chaîne YouTube (optionnel)';

