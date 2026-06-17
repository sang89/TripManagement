-- ─────────────────────────────────────────────────────────────────────────────
-- Per-app avatar URLs
--
-- Both apps share the same Supabase project and user accounts, but profile
-- photos should be independent per app.
--
-- Strategy:
--   • user_profiles.avatar_url    → PropertyManagement photo (existing)
--   • user_profiles.trip_avatar_url → TripManagement photo (new)
--
-- A new SECURITY DEFINER RPC get_trip_profile_names is added for TripManagement.
-- It returns COALESCE(trip_avatar_url, avatar_url) so existing entries that
-- pre-date this migration still show the shared photo until a trip-specific one
-- is uploaded.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS trip_avatar_url text;

-- ─── RPC: get_trip_profile_names ─────────────────────────────────────────────
-- Mirrors get_profile_names but returns the trip-specific avatar URL,
-- falling back to the shared avatar_url when no trip photo has been set.
-- SECURITY DEFINER so callers can read other users' profiles (same as
-- the existing get_profile_names RPC).
DROP FUNCTION IF EXISTS public.get_trip_profile_names(uuid[]);

CREATE FUNCTION public.get_trip_profile_names(p_user_ids uuid[])
RETURNS TABLE(
  user_id    uuid,
  full_name  text,
  email      text,
  phone      text,
  avatar_url text
)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT
    up.user_id,
    up.full_name,
    au.email,
    up.phone,
    COALESCE(up.trip_avatar_url, up.avatar_url) AS avatar_url
  FROM public.user_profiles up
  JOIN auth.users au ON au.id = up.user_id
  WHERE up.user_id = ANY(p_user_ids);
$$;

GRANT EXECUTE ON FUNCTION public.get_trip_profile_names(uuid[]) TO authenticated;
