-- Global user block list.
-- If User A blocks User B:
--   - B cannot look up A via find_user_by_contact (add-member sheet)
--   - B cannot send A a friend request (RLS enforcement in next migration)
--   - Any existing friendship between A and B is removed atomically

CREATE TABLE user_blocks (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);

ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_blocks_select" ON user_blocks
  FOR SELECT USING (blocker_id = auth.uid());

CREATE POLICY "user_blocks_insert" ON user_blocks
  FOR INSERT WITH CHECK (blocker_id = auth.uid());

CREATE POLICY "user_blocks_delete" ON user_blocks
  FOR DELETE USING (blocker_id = auth.uid());

-- Atomically removes any friendship and inserts the block record.
CREATE FUNCTION block_user(p_blocked_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM friendships
  WHERE (requester_id = auth.uid() AND addressee_id = p_blocked_id)
     OR (requester_id = p_blocked_id AND addressee_id = auth.uid());

  INSERT INTO user_blocks (blocker_id, blocked_id)
  VALUES (auth.uid(), p_blocked_id)
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;
END;
$$;

REVOKE EXECUTE ON FUNCTION block_user(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION block_user(uuid) TO authenticated;

-- Returns display info for all users the caller has blocked.
CREATE FUNCTION get_blocked_users()
RETURNS TABLE(user_id uuid, full_name text, avatar_url text, blocked_at timestamptz)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT up.user_id,
         COALESCE(NULLIF(TRIM(up.full_name), ''), 'Unknown') AS full_name,
         up.avatar_url,
         ub.created_at
  FROM   user_blocks ub
  JOIN   user_profiles up ON up.user_id = ub.blocked_id
  WHERE  ub.blocker_id = auth.uid()
  ORDER BY ub.created_at DESC;
$$;

REVOKE EXECUTE ON FUNCTION get_blocked_users() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION get_blocked_users() TO authenticated;
