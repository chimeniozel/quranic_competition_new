-- RPC function to delete a user from Supabase Auth
-- This function uses SECURITY DEFINER to run with elevated privileges
-- Note: Direct deletion from auth.users may require service role key
-- Alternative: Use Supabase Admin API or Edge Function with service role key

CREATE OR REPLACE FUNCTION delete_user_from_auth(user_id_to_delete UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  user_exists BOOLEAN;
  deleted_count INTEGER;
BEGIN
  -- Check if user exists in auth.users
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = user_id_to_delete) INTO user_exists;
  
  IF NOT user_exists THEN
    RAISE NOTICE 'User % does not exist in auth.users', user_id_to_delete;
    RETURN FALSE;
  END IF;
  
  -- Delete user from auth.users
  -- This requires service role privileges or proper RLS policies
  DELETE FROM auth.users WHERE id = user_id_to_delete;
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  IF deleted_count > 0 THEN
    RAISE NOTICE 'User % successfully deleted from auth.users', user_id_to_delete;
    RETURN TRUE;
  ELSE
    RAISE NOTICE 'User % was not deleted (may require service role)', user_id_to_delete;
    RETURN FALSE;
  END IF;
EXCEPTION
  WHEN insufficient_privilege THEN
    RAISE EXCEPTION 'Insufficient privileges to delete user from auth.users. Service role key may be required.';
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error deleting user from auth: %', SQLERRM;
END;
$$;

-- Grant execute permission to authenticated users
-- IMPORTANT: Consider restricting this to admins only for security
-- You can create a policy or check user role inside the function
GRANT EXECUTE ON FUNCTION delete_user_from_auth(UUID) TO authenticated;

-- Add a comment
COMMENT ON FUNCTION delete_user_from_auth(UUID) IS 'Deletes a user from auth.users table. Requires service role privileges or SECURITY DEFINER.';

