-- Friendships table: tracks friend requests and accepted friendships.
-- One row per directed pair (requester, addressee); the unique constraint
-- prevents duplicate requests.  Both parties can see the row (SELECT RLS).

CREATE TABLE friendships (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  addressee_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status       text NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending', 'accepted', 'declined', 'removed')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT friendships_pair_unique UNIQUE (requester_id, addressee_id)
);

ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;

-- Either party can read the row.
CREATE POLICY friendships_select ON friendships FOR SELECT
  USING (requester_id = auth.uid() OR addressee_id = auth.uid());

-- Only the requester can create a request.
CREATE POLICY friendships_insert ON friendships FOR INSERT
  WITH CHECK (requester_id = auth.uid());

-- Either party can update (addressee accepts/declines; either can set 'removed').
CREATE POLICY friendships_update ON friendships FOR UPDATE
  USING (requester_id = auth.uid() OR addressee_id = auth.uid());

-- Include friendships in Realtime so the client receives live updates.
ALTER PUBLICATION supabase_realtime ADD TABLE friendships;

-- REPLICA IDENTITY FULL so DELETE payloads contain both user IDs.
ALTER TABLE friendships REPLICA IDENTITY FULL;

-- ─── search_users RPC ─────────────────────────────────────────────────────────
-- Returns users matching the query, excluding the caller and anyone already
-- in a pending/accepted friendship with the caller.
CREATE OR REPLACE FUNCTION search_users(p_query text)
RETURNS TABLE(user_id uuid, full_name text, email text)
LANGUAGE plpgsql SECURITY DEFINER AS $$
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

GRANT EXECUTE ON FUNCTION search_users(text) TO authenticated;
