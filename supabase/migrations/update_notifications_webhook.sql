-- Webhook des notifications : nettoyage et durcissement
--
-- État constaté sur l'instance (SELECT sur pg_trigger) : DEUX triggers
-- AFTER INSERT coexistent sur `public.notifications`.
--
--   1. `notifications` — webhook créé depuis le tableau de bord. Il appelle
--      déjà la bonne URL (.../functions/v1/send_fcm_notification) et
--      fonctionne. RIEN À CHANGER de ce côté.
--
--   2. `trigger_notify_fcm_function` — duplicata écrit à la main, qui appelle
--      la même fonction. Il échoue en réalité à chaque insertion : son
--      appel `net.http_post(url, headers, payload)` ne correspond à aucune
--      signature de pg_net, dont l'ordre des paramètres est
--      (url, body, params, headers, timeout). L'erreur est avalée par son
--      bloc EXCEPTION, qui se contente d'un RAISE WARNING.
--
-- Ce fichier supprime donc le duplicata, et propose de remplacer la clé
-- portée par le webhook.

-- ---------------------------------------------------------------------------
-- 1. Supprimer le trigger mort et sa fonction
-- ---------------------------------------------------------------------------

DROP TRIGGER IF EXISTS trigger_notify_fcm_function ON public.notifications;
DROP FUNCTION IF EXISTS notify_fcm_function();

-- ---------------------------------------------------------------------------
-- 2. (Recommandé) Faire porter au webhook une clé secrète révocable
--
-- Le webhook transporte aujourd'hui la clé `service_role` historique dans son
-- en-tête Authorization. Cette clé ne peut être invalidée qu'en régénérant le
-- secret JWT du projet — ce qui invaliderait du même coup la clé `anon` et
-- bloquerait toutes les applications déjà installées.
--
-- Une clé secrète du nouveau système (`sb_secret_...`, onglet « Publishable
-- and secret API keys ») se révoque individuellement, sans rien casser.
--
-- ⚠️ Remplacer <SECRET_KEY> ci-dessous. Ne jamais enregistrer la valeur dans
-- ce fichier ni la transmettre : elle contourne toutes les politiques RLS.
-- ---------------------------------------------------------------------------

-- DROP TRIGGER IF EXISTS notifications ON public.notifications;
--
-- CREATE TRIGGER notifications
--   AFTER INSERT ON public.notifications
--   FOR EACH ROW
--   EXECUTE FUNCTION supabase_functions.http_request(
--     'https://slwgmpqpevsodtctpmwz.supabase.co/functions/v1/send_fcm_notification',
--     'POST',
--     '{"Content-type":"application/json","Authorization":"Bearer <SECRET_KEY>"}',
--     '{}',
--     '5000'
--   );

-- ---------------------------------------------------------------------------
-- 3. Vérification
-- ---------------------------------------------------------------------------
--   SELECT tgname, pg_get_triggerdef(oid)
--   FROM pg_trigger
--   WHERE tgrelid = 'public.notifications'::regclass AND NOT tgisinternal;
--
-- Attendu : UN SEUL trigger, `notifications`, pointant vers
-- .../functions/v1/send_fcm_notification
-- Deux triggers actifs = chaque appareil reçoit la notification en double.
