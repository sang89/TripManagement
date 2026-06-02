-- Batch-lookup RPC for the "Find from Contacts" feature.
-- Takes arrays of phone numbers and emails extracted from the caller's device
-- contacts, and returns matching registered users.
--
-- Phones are normalised (non-digits stripped) before comparison so that
-- +1 (555) 555-5555 matches 15555555555 regardless of storage format.
--
-- Results exclude:
--   - The caller themselves
--   - Users blocked in either direction
--   - Users already connected (pending or accepted friendship)

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
    up.avatar_url,
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
