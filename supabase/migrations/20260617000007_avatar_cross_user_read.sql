-- ─────────────────────────────────────────────────────────────────────────────
-- Avatar storage: allow any authenticated user to read any avatar.
--
-- Profile pictures must be visible to other event members and friends.
-- The previous policy only allowed each user to read their own avatar path,
-- which prevented SupabaseImage from creating signed URLs for other users'
-- photos when rendering guest lists, friend lists, etc.
--
-- Also: remove the COALESCE(trip_avatar_url, avatar_url) fallback from both
-- RPCs so TripManagement never shows a PropertyManagement avatar.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Widen the read policy ────────────────────────────────────────────────────

DROP POLICY IF EXISTS "Users can read their own avatars" ON storage.objects;

CREATE POLICY "Authenticated users can read avatars"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'avatars');

-- 2. get_trip_profile_names — return trip_avatar_url only ─────────────────────
-- Remove the COALESCE fallback to avatar_url so the app never shows
-- a PropertyManagement avatar in TripManagement context.

CREATE OR REPLACE FUNCTION public.get_trip_profile_names(p_user_ids uuid[])
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
    up.trip_avatar_url AS avatar_url
  FROM public.user_profiles up
  JOIN auth.users au ON au.id = up.user_id
  WHERE up.user_id = ANY(p_user_ids);
$$;

GRANT EXECUTE ON FUNCTION public.get_trip_profile_names(uuid[]) TO authenticated;

-- 3. find_users_by_contacts — return trip_avatar_url only ─────────────────────

CREATE OR REPLACE FUNCTION find_users_by_contacts(
  p_phones text[],
  p_emails text[]
)
RETURNS TABLE(
  user_id       uuid,
  full_name     text,
  avatar_url    text,
  matched_phone text,
  matched_email text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT DISTINCT ON (up.user_id)
    up.user_id,
    COALESCE(NULLIF(TRIM(up.full_name), ''), split_part(au.email, '@', 1), up.user_id::text) AS full_name,
    up.trip_avatar_url AS avatar_url,
    up.phone  AS matched_phone,
    au.email  AS matched_email
  FROM user_profiles up
  JOIN auth.users au ON au.id = up.user_id
  WHERE
    up.user_id <> auth.uid()
    AND NOT EXISTS (
      SELECT 1 FROM user_blocks ub
      WHERE (ub.blocker_id = auth.uid() AND ub.blocked_id = up.user_id)
         OR (ub.blocker_id = up.user_id  AND ub.blocked_id = auth.uid())
    )
    AND NOT EXISTS (
      SELECT 1 FROM friendships f
      WHERE (
              (f.requester_id = auth.uid() AND f.addressee_id = up.user_id)
           OR (f.requester_id = up.user_id  AND f.addressee_id = auth.uid())
            )
        AND f.status IN ('pending', 'accepted')
    )
    AND (
      (
        cardinality(p_phones) > 0
        AND regexp_replace(up.phone, '\D', '', 'g') <> ''
        AND regexp_replace(up.phone, '\D', '', 'g') = ANY(
              SELECT regexp_replace(p, '\D', '', 'g')
              FROM unnest(p_phones) AS p
            )
      )
      OR
      (
        cardinality(p_emails) > 0
        AND LOWER(au.email) = ANY(
              SELECT LOWER(e) FROM unnest(p_emails) AS e
            )
      )
    );
$$;

REVOKE EXECUTE ON FUNCTION find_users_by_contacts(text[], text[]) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION find_users_by_contacts(text[], text[]) TO authenticated;
