-- Ciblage des notifications : chaque utilisateur ne reçoit que les siennes
--
-- Problème corrigé ici : l'application s'abonne à TOUTES les insertions de
-- la table `notifications` et écarte ensuite, côté client, celles qui ne la
-- concernent pas. Le tri fonctionne à l'affichage, mais la ligne a déjà
-- voyagé jusqu'à l'appareil : la notification personnelle d'un utilisateur
-- (titre et contenu compris) transite par tous les appareils connectés.
--
-- La seule barrière efficace est côté serveur. Avec ces règles, Realtime ne
-- diffuse à un client que les lignes qu'il a le droit de lire, et le filtre
-- appliqué dans l'application devient une simple seconde barrière.

-- ---------------------------------------------------------------------------
-- 1. notifications : publiques (user_id NULL) ou personnelles
-- ---------------------------------------------------------------------------

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_select_own_or_public" ON notifications;
CREATE POLICY "notifications_select_own_or_public"
  ON notifications
  FOR SELECT
  USING (
    user_id IS NULL
    OR user_id = auth.uid()
  );

-- Marquer comme lue : uniquement ses propres notifications.
-- (les notifications publiques sont marquées lues sur l'appareil, jamais en base)
DROP POLICY IF EXISTS "notifications_update_own" ON notifications;
CREATE POLICY "notifications_update_own"
  ON notifications
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- L'envoi reste réservé aux comptes authentifiés (administrateurs).
-- À restreindre davantage si un rôle dédié existe dans `profiles`.
DROP POLICY IF EXISTS "notifications_insert_authenticated" ON notifications;
CREATE POLICY "notifications_insert_authenticated"
  ON notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- 2. fcm_tokens : un appareil ne doit pas pouvoir lire les jetons des autres
-- ---------------------------------------------------------------------------

ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Les participants ne sont pas connectés : leurs jetons ont user_id NULL et
-- doivent rester enregistrables. On autorise donc l'écriture, mais pas la
-- lecture des jetons d'autrui.
DROP POLICY IF EXISTS "fcm_tokens_insert_any" ON fcm_tokens;
CREATE POLICY "fcm_tokens_insert_any"
  ON fcm_tokens
  FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "fcm_tokens_update_own_device" ON fcm_tokens;
CREATE POLICY "fcm_tokens_update_own_device"
  ON fcm_tokens
  FOR UPDATE
  USING (user_id IS NULL OR user_id = auth.uid())
  WITH CHECK (user_id IS NULL OR user_id = auth.uid());

DROP POLICY IF EXISTS "fcm_tokens_select_own" ON fcm_tokens;
CREATE POLICY "fcm_tokens_select_own"
  ON fcm_tokens
  FOR SELECT
  USING (user_id IS NULL OR user_id = auth.uid());

-- L'Edge Function utilise la clé `service_role`, qui contourne RLS : l'envoi
-- des notifications push continue de fonctionner normalement.

-- ---------------------------------------------------------------------------
-- 3. Contrainte d'unicité sur le jeton — INDISPENSABLE
--
-- L'application enregistre le jeton avec :
--     upsert(data, onConflict: 'fcm_token')
--
-- PostgREST traduit cela en « INSERT ... ON CONFLICT (fcm_token) », ce qui
-- exige une contrainte unique sur cette colonne. Sans elle, PostgreSQL
-- répond « there is no unique or exclusion constraint matching the ON
-- CONFLICT specification » : CHAQUE enregistrement de jeton échoue, la table
-- reste vide, et plus aucune notification push n'est distribuée.
-- ---------------------------------------------------------------------------

CREATE UNIQUE INDEX IF NOT EXISTS fcm_tokens_token_uidx
  ON fcm_tokens (fcm_token);

-- Un seul jeton actif par appareil
CREATE INDEX IF NOT EXISTS fcm_tokens_device_active_idx
  ON fcm_tokens (device_id, is_active);

-- ---------------------------------------------------------------------------
-- 4. Diffusion temps réel de la table
-- ---------------------------------------------------------------------------

-- Ajout idempotent : relancer le script ne doit pas échouer si la table est
-- déjà publiée.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;
