-- Re-add avatar_url to get_profile_names so the chat UI can show profile pics.

DROP FUNCTION IF EXISTS get_profile_names(uuid[]);

CREATE OR REPLACE FUNCTION get_profile_names(p_user_ids uuid[])
RETURNS TABLE(user_id uuid, full_name text, email text, phone text, avatar_url text)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    up.user_id,
    COALESCE(
      NULLIF(TRIM(up.full_name), ''),
      split_part(au.email, '@', 1),
      up.user_id::text
    )            AS full_name,
    au.email::text,
    au.phone::text,
    up.avatar_url
  FROM user_profiles up
  JOIN auth.users au ON au.id = up.user_id
  WHERE up.user_id = ANY(p_user_ids);
$$;

REVOKE EXECUTE ON FUNCTION get_profile_names(uuid[]) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION get_profile_names(uuid[]) TO authenticated;
