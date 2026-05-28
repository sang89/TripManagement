-- Extend get_profile_names to also return avatar_url.
-- Changing a TABLE-returning function's column list requires DROP + recreate
-- (CREATE OR REPLACE cannot change the return type in PostgreSQL).

DROP FUNCTION IF EXISTS get_profile_names(uuid[]);

CREATE FUNCTION get_profile_names(p_user_ids uuid[])
RETURNS TABLE(user_id uuid, full_name text, avatar_url text)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    up.user_id,
    COALESCE(
      NULLIF(TRIM(up.full_name), ''),
      au.email,
      up.user_id::text
    ) AS full_name,
    up.avatar_url
  FROM user_profiles up
  JOIN auth.users au ON au.id = up.user_id
  WHERE up.user_id = ANY(p_user_ids);
$$;

REVOKE EXECUTE ON FUNCTION get_profile_names(uuid[]) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION get_profile_names(uuid[]) TO authenticated;
