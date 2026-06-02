-- Enforce user_blocks in find_user_by_contact, search_users, and friendships RLS.

-- ─── find_user_by_contact: hide callers blocked by the found user ──────────────

CREATE OR REPLACE FUNCTION public.find_user_by_contact(
  p_email text DEFAULT NULL,
  p_phone text DEFAULT NULL
)
RETURNS TABLE(
  user_id    uuid,
  full_name  text,
  job_title  text,
  phone      text,
  avatar_url text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    up.user_id,
    up.full_name,
    up.job_title,
    up.phone,
    up.avatar_url
  FROM public.user_profiles up
  JOIN auth.users au ON au.id = up.user_id
  WHERE (
    (p_email IS NOT NULL AND p_email <> ''
     AND lower(au.email) = lower(p_email))
    OR
    (p_phone IS NOT NULL AND p_phone <> ''
     AND up.phone = p_phone)
  )
  -- Do not surface a user who has blocked the caller.
  AND NOT EXISTS (
    SELECT 1 FROM user_blocks
    WHERE blocker_id = up.user_id AND blocked_id = auth.uid()
  )
  LIMIT 1;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.find_user_by_contact(text, text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.find_user_by_contact(text, text) TO authenticated;

-- ─── search_users: hide blocked users in both directions ──────────────────────

DROP FUNCTION IF EXISTS search_users(text);

CREATE OR REPLACE FUNCTION search_users(p_query text)
RETURNS TABLE(user_id uuid, full_name text, email text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_digits text := regexp_replace(p_query, '[^0-9]', '', 'g');
BEGIN
  RETURN QUERY
  SELECT up.user_id,
         up.full_name,
         u.email::text
  FROM   user_profiles up
  JOIN   auth.users    u ON u.id = up.user_id
  WHERE  up.user_id <> auth.uid()
    AND  (
           up.full_name ILIKE '%' || p_query || '%'
           OR u.email   ILIKE '%' || p_query || '%'
           OR (
             v_digits <> ''
             AND regexp_replace(COALESCE(u.phone, ''), '[^0-9]', '', 'g')
                   LIKE '%' || v_digits || '%'
           )
         )
    -- Exclude existing/pending friends
    AND  up.user_id NOT IN (
           SELECT CASE
                    WHEN requester_id = auth.uid() THEN addressee_id
                    ELSE requester_id
                  END
           FROM   friendships
           WHERE  (requester_id = auth.uid() OR addressee_id = auth.uid())
             AND  status IN ('pending', 'accepted')
         )
    -- Exclude users who blocked the caller OR who the caller has blocked
    AND NOT EXISTS (
      SELECT 1 FROM user_blocks ub
      WHERE (ub.blocker_id = up.user_id AND ub.blocked_id = auth.uid())
         OR (ub.blocker_id = auth.uid() AND ub.blocked_id = up.user_id)
    )
  ORDER BY up.full_name
  LIMIT  20;
END;
$$;

REVOKE EXECUTE ON FUNCTION search_users(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION search_users(text) TO authenticated;

-- ─── friendships_insert RLS: block friend requests to users who blocked you ───

DROP POLICY IF EXISTS friendships_insert ON friendships;

CREATE POLICY friendships_insert ON friendships
  FOR INSERT
  WITH CHECK (
    requester_id = auth.uid()
    AND NOT EXISTS (
      SELECT 1 FROM user_blocks
      WHERE blocker_id = addressee_id AND blocked_id = auth.uid()
    )
  );
