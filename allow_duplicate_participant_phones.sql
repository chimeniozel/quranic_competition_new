-- Nettoie les anciennes contraintes d'unicité sur le champ phone
-- puis applique une contrainte UNIQUE par compétition (competition_id, phone).

DO $$
DECLARE
  constraint_record record;
BEGIN
  -- Supprimer la contrainte UNIQUE si elle existe (nom par défaut Supabase/Postgres)
  IF EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE table_name = 'participants'
      AND constraint_type = 'UNIQUE'
      AND constraint_name = 'participants_phone_key'
  ) THEN
    ALTER TABLE participants DROP CONSTRAINT participants_phone_key;
  END IF;

  -- Supprimer la contrainte personnalisée unique_phone_per_competition si présente
  IF EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE table_name = 'participants'
      AND constraint_type = 'UNIQUE'
      AND constraint_name = 'unique_phone_per_competition'
  ) THEN
    ALTER TABLE participants DROP CONSTRAINT unique_phone_per_competition;
  END IF;

  -- Supprimer un éventuel index unique personnalisé sur phone
  IF EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'participants_phone_idx'
  ) THEN
    DROP INDEX public.participants_phone_idx;
  END IF;

  -- Supprimer un index (quelle que soit sa dénomination) qui serait unique sur phone
  FOR constraint_record IN
    SELECT indexname
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename = 'participants'
      AND indexdef ILIKE '%UNIQUE%' 
      AND indexdef ILIKE '%phone%'
  LOOP
    EXECUTE format('DROP INDEX IF EXISTS public.%I', constraint_record.indexname);
  END LOOP;

  -- Supprimer l'ancien index non unique si présent
  IF EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'participants_phone_non_unique_idx'
  ) THEN
    DROP INDEX public.participants_phone_non_unique_idx;
  END IF;

  -- Créer un index UNIQUE sur (competition_id, phone) pour empêcher les doublons dans une même compétition
  IF NOT EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'participants_competition_phone_unique'
  ) THEN
    CREATE UNIQUE INDEX participants_competition_phone_unique
      ON public.participants (competition_id, phone);
  END IF;
END;
$$;


