-- Returns the canonical display name for a list of user IDs, bypassing
-- user_profiles RLS (which only grants access to a user's own row).
--
-- Used by TripProvider._enrichMemberNames() so every member's device can
-- show real profile names for all trip members without changing user_profiles
-- RLS or adding a cross-user SELECT policy.
--
-- Falls back to auth.users.email when full_name is blank (e.g. SSO accounts
-- that haven't filled in a name yet), then to the UUID string as a last resort.
--
-- GRANT: only authenticated users may call this function.

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
      au.email,
      up.user_id::text
    ) AS full_name
  FROM user_profiles up
  JOIN auth.users au ON au.id = up.user_id
  WHERE up.user_id = ANY(p_user_ids);
$$;

-- Restrict to logged-in users only (default EXECUTE is PUBLIC; tighten it).
REVOKE EXECUTE ON FUNCTION get_profile_names(uuid[]) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION get_profile_names(uuid[]) TO authenticated;
