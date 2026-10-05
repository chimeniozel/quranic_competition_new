-- Suppression groupée des comptes non confirmés (page « إدارة المستخدمين »)
--
-- Un seul appel supprime tout le lot côté serveur, au lieu de 3 à 4 requêtes
-- par compte depuis l'application.
--
-- Garde-fous, vérifiés ici et non seulement dans l'interface :
--   * l'appelant doit avoir le droit de suppression (super_admin par défaut,
--     ou colonne profiles.can_delete à true) ;
--   * seuls les comptes non confirmés (is_validated = false) sont supprimés ;
--   * jamais un super_admin, ni le compte de l'appelant ;
--   * un محكم déjà affecté à une جولة est ignoré.
--
-- Retour : {"deleted": [uuid...], "skipped": [uuid...]}. Les identifiants
-- absents des deux listes n'étaient pas supprimables (déjà supprimés,
-- confirmés entre-temps...).

CREATE OR REPLACE FUNCTION public.delete_unvalidated_users(user_ids uuid[])
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  caller_id uuid := auth.uid();
  caller jsonb;
  caller_can_delete boolean;
  skipped_ids uuid[];
  deleted_ids uuid[];
BEGIN
  IF caller_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  -- to_jsonb : fonctionne même si la colonne can_delete n'existe pas
  SELECT to_jsonb(p) INTO caller FROM public.profiles p WHERE p.id = caller_id;

  caller_can_delete := CASE
    WHEN caller IS NULL THEN false
    WHEN caller->>'can_delete' IS NOT NULL THEN (caller->>'can_delete')::boolean
    ELSE caller->>'role' = 'super_admin'
  END;

  IF NOT caller_can_delete THEN
    RAISE EXCEPTION 'PERMISSION_DENIED';
  END IF;

  -- محكمون affectés à une جولة : conservés
  SELECT coalesce(array_agg(DISTINCT a.user_id), '{}')
  INTO skipped_ids
  FROM public.round_jury_assignments a
  WHERE a.user_id = ANY (user_ids);

  -- Comptes réellement supprimables
  SELECT coalesce(array_agg(p.id), '{}')
  INTO deleted_ids
  FROM public.profiles p
  WHERE p.id = ANY (user_ids)
    AND coalesce(p.is_validated, false) = false
    AND p.role IS DISTINCT FROM 'super_admin'
    AND p.id <> caller_id
    AND NOT (p.id = ANY (skipped_ids));

  DELETE FROM public.profiles WHERE id = ANY (deleted_ids);
  DELETE FROM auth.users WHERE id = ANY (deleted_ids);

  RETURN jsonb_build_object('deleted', deleted_ids, 'skipped', skipped_ids);
END;
$$;

REVOKE ALL ON FUNCTION public.delete_unvalidated_users(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_unvalidated_users(uuid[]) TO authenticated;
