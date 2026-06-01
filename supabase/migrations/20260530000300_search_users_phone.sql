-- Extend search_users to also match auth.users.phone.
-- Digits are stripped from both the query and the stored phone number before
-- comparison so formats like "+1 (555) 123-4567" and "5551234567" both match.

DROP FUNCTION IF EXISTS search_users(text);

CREATE OR REPLACE FUNCTION search_users(p_query text)
RETURNS TABLE(user_id uuid, full_name text, email text)
LANGUAGE plpgsql SECURITY DEFINER AS $$
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
    AND  up.user_id NOT IN (
           SELECT CASE
                    WHEN requester_id = auth.uid() THEN addressee_id
                    ELSE requester_id
                  END
           FROM   friendships
           WHERE  (requester_id = auth.uid() OR addressee_id = auth.uid())
             AND  status IN ('pending', 'accepted')
         )
  ORDER BY up.full_name
  LIMIT  20;
END;
$$;

REVOKE EXECUTE ON FUNCTION search_users(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION search_users(text) TO authenticated;
