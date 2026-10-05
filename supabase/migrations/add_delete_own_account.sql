-- Suppression de son propre compte depuis les paramètres du compte
--
-- Le client Flutter n'a que la clé anon : il ne peut pas appeler
-- auth.admin.deleteUser. Cette fonction SECURITY DEFINER supprime
-- uniquement l'utilisateur connecté (auth.uid()), jamais un autre compte.
--
-- Le dernier super admin ne peut pas supprimer son compte, pour ne pas
-- laisser l'application sans administrateur général.

CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  current_user_id uuid := auth.uid();
  current_role_code text;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT role INTO current_role_code
  FROM public.profiles
  WHERE id = current_user_id;

  IF current_role_code = 'super_admin' AND (
    SELECT count(*) FROM public.profiles WHERE role = 'super_admin'
  ) <= 1 THEN
    RAISE EXCEPTION 'LAST_SUPER_ADMIN';
  END IF;

  DELETE FROM public.round_jury_assignments WHERE user_id = current_user_id;
  DELETE FROM public.profiles WHERE id = current_user_id;
  DELETE FROM auth.users WHERE id = current_user_id;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_own_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;
