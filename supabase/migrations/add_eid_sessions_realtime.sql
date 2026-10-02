-- ===========================================================================
-- Diffusion temps réel de la table eid_sessions (« فسحة العيد »)
-- ===========================================================================
--
-- L'accueil participant s'abonne aux changements de eid_sessions pour
-- masquer immédiatement une فسحة désactivée ou supprimée. Sans cette
-- publication, Realtime ne transmet aucun événement et la فسحة reste
-- affichée jusqu'au redémarrage de l'application.

-- Ajout idempotent : relancer le script ne doit pas échouer si la table est
-- déjà publiée.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'eid_sessions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.eid_sessions;
  END IF;
END $$;
