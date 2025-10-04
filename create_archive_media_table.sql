-- Script pour créer la table des médias d'archives
-- Exécuter ce script dans l'éditeur SQL de Supabase

-- Table: public.archive_media
CREATE TABLE IF NOT EXISTS public.archive_media (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    archive_id UUID NOT NULL REFERENCES public.competition_archives(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('video', 'image')),
    url TEXT NOT NULL,
    thumbnail_url TEXT,
    title TEXT,
    description TEXT,
    "order" INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_archive_media_archive_id 
ON public.archive_media(archive_id);

CREATE INDEX IF NOT EXISTS idx_archive_media_type 
ON public.archive_media(type);

CREATE INDEX IF NOT EXISTS idx_archive_media_order 
ON public.archive_media(archive_id, "order");

-- Politiques RLS (Row Level Security)

-- Activer RLS
ALTER TABLE public.archive_media ENABLE ROW LEVEL SECURITY;

-- Politique pour permettre la lecture à tous les utilisateurs authentifiés
CREATE POLICY "Allow authenticated users to read archive media" ON public.archive_media
FOR SELECT USING (auth.role() = 'authenticated');

-- Politique pour permettre l'insertion aux utilisateurs authentifiés
CREATE POLICY "Allow authenticated users to insert archive media" ON public.archive_media
FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Politique pour permettre la mise à jour aux utilisateurs authentifiés
CREATE POLICY "Allow authenticated users to update archive media" ON public.archive_media
FOR UPDATE USING (auth.role() = 'authenticated');

-- Politique pour permettre la suppression aux utilisateurs authentifiés
CREATE POLICY "Allow authenticated users to delete archive media" ON public.archive_media
FOR DELETE USING (auth.role() = 'authenticated');

-- Politique pour permettre la lecture publique des médias d'archives actives
CREATE POLICY "Allow public read access to active archive media" ON public.archive_media
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.competition_archives 
        WHERE id = archive_media.archive_id 
        AND is_active = true
    )
);

-- Commentaires sur la table et les colonnes
COMMENT ON TABLE public.archive_media IS 'Médias (vidéos et images) des archives de compétitions';
COMMENT ON COLUMN public.archive_media.id IS 'Identifiant unique du média';
COMMENT ON COLUMN public.archive_media.archive_id IS 'Référence vers l''archive de compétition';
COMMENT ON COLUMN public.archive_media.type IS 'Type de média (video ou image)';
COMMENT ON COLUMN public.archive_media.url IS 'URL du média';
COMMENT ON COLUMN public.archive_media.thumbnail_url IS 'URL de la miniature (pour les vidéos)';
COMMENT ON COLUMN public.archive_media.title IS 'Titre du média (optionnel)';
COMMENT ON COLUMN public.archive_media.description IS 'Description du média (optionnel)';
COMMENT ON COLUMN public.archive_media."order" IS 'Ordre d''affichage du média dans l''archive';
COMMENT ON COLUMN public.archive_media.created_at IS 'Date de création';

-- Données d'exemple (optionnel)
-- INSERT INTO public.archive_media (
--     archive_id,
--     type,
--     url,
--     title,
--     description,
--     "order"
-- ) VALUES (
--     (SELECT id FROM public.competition_archives LIMIT 1),
--     'video',
--     'https://www.youtube.com/watch?v=example',
--     'Vidéo de la compétition',
--     'Vidéo complète de la compétition',
--     1
-- ),
-- (
--     (SELECT id FROM public.competition_archives LIMIT 1),
--     'image',
--     'https://example.com/image1.jpg',
--     'Photo de la compétition',
--     'Photo de groupe des participants',
--     2
-- );
