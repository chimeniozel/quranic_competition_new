-- Script pour créer la table des archives de compétitions
-- Exécuter ce script dans l'éditeur SQL de Supabase

-- Table: public.competition_archives
CREATE TABLE IF NOT EXISTS public.competition_archives (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    version_id UUID NOT NULL REFERENCES public.competition_versions(id) ON DELETE CASCADE,
    version_name TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    event_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_competition_archives_version_id 
ON public.competition_archives(version_id);

CREATE INDEX IF NOT EXISTS idx_competition_archives_event_date 
ON public.competition_archives(event_date);

CREATE INDEX IF NOT EXISTS idx_competition_archives_is_active 
ON public.competition_archives(is_active);

CREATE INDEX IF NOT EXISTS idx_competition_archives_created_at 
ON public.competition_archives(created_at);

-- Commentaires sur la table et les colonnes
COMMENT ON TABLE public.competition_archives IS 'Archives des compétitions avec vidéos et images';
COMMENT ON COLUMN public.competition_archives.id IS 'Identifiant unique de l''archive';
COMMENT ON COLUMN public.competition_archives.version_id IS 'Référence vers la version de compétition';
COMMENT ON COLUMN public.competition_archives.version_name IS 'Nom de la version (mis à jour automatiquement)';
COMMENT ON COLUMN public.competition_archives.title IS 'Titre de l''archive';
COMMENT ON COLUMN public.competition_archives.description IS 'Description de l''archive';
COMMENT ON COLUMN public.competition_archives.event_date IS 'Date de l''événement';
COMMENT ON COLUMN public.competition_archives.is_active IS 'Statut d''activation de l''archive';
COMMENT ON COLUMN public.competition_archives.created_at IS 'Date de création';
COMMENT ON COLUMN public.competition_archives.updated_at IS 'Date de dernière mise à jour';

-- Données d'exemple (optionnel)
-- INSERT INTO public.competition_archives (
--     version_id,
--     version_name,
--     title,
--     description,
--     event_date,
--     is_active
-- ) VALUES (
--     (SELECT id FROM public.competition_versions LIMIT 1),
--     'Version d''exemple',
--     'Archive d''exemple',
--     'Description de l''archive d''exemple',
--     NOW() - INTERVAL '30 days',
--     true
-- );
