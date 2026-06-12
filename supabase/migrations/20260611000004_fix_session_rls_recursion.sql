-- Fix: infinite recursion between event_sessions and event_session_roster RLS.
--
-- The "members can read sessions" policy added in 20260611000003 checked
-- event_session_roster to allow roster members to see private sessions.
-- The "event member reads roster" policy checks event_sessions to verify
-- access. This creates a circular dependency → 42P17 infinite recursion.
--
-- Solution: wrap the roster membership check in a SECURITY DEFINER function
-- so it queries event_session_roster without triggering its own RLS policy,
-- breaking the cycle.

CREATE OR REPLACE FUNCTION user_is_in_session_roster(p_session_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM event_session_roster
    WHERE session_id = p_session_id
      AND user_id    = auth.uid()
  );
$$;

REVOKE EXECUTE ON FUNCTION user_is_in_session_roster(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION user_is_in_session_roster(uuid) TO authenticated;

-- Recreate the policy using the helper to avoid recursion.
DROP POLICY IF EXISTS "members can read sessions" ON event_sessions;

CREATE POLICY "members can read sessions" ON event_sessions
  FOR SELECT USING (
    -- Public sessions: visible to any accepted/pending event member
    (
      is_public = true
      AND EXISTS (
        SELECT 1 FROM event_guests
        WHERE event_id = event_sessions.event_id
          AND user_id  = auth.uid()
          AND status NOT IN ('left', 'declined')
      )
    )
    -- Private sessions: visible only to members who already joined via QR/link
    OR user_is_in_session_roster(event_sessions.id)
  );
