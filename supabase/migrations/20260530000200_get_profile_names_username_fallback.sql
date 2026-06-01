-- Change the email fallback in get_profile_names to use only the local part
-- (before @) so users without a full_name set see "alice" instead of
-- "alice@example.com" in trip member lists and chat.

DROP FUNCTION IF EXISTS get_profile_names(uuid[]);

CREATE OR REPLACE FUNCTION get_profile_names(p_user_ids uuid[])
RETURNS TABLE(user_id uuid, full_name text)
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
    ) AS full_name
  FROM user_profiles up
  JOIN auth.users au ON au.id = up.user_id
  WHERE up.user_id = ANY(p_user_ids);
$$;
