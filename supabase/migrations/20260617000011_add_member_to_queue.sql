-- ─────────────────────────────────────────────────────────────────────────────
-- RPC: add_member_to_queue
--
-- Allows any event member to add another person (with or without an app
-- account) to a specific queue activity.  Non-app members (anonymous guests
-- on the roster) have user_id = NULL; only display_name is stored.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.add_member_to_queue(
  p_activity_id  uuid,
  p_user_id      uuid,     -- NULL for anonymous / non-app guests
  p_display_name text,
  p_avatar_url   text      -- NULL ok
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid      uuid    := auth.uid();
  v_event_id uuid;
  v_spots    integer;
  v_claimed  bigint;
BEGIN
  SELECT es.event_id, a.players_per_round
  INTO v_event_id, v_spots
  FROM session_queue_activities a
  JOIN event_sessions es ON es.id = a.session_id
  WHERE a.id = p_activity_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'activity_not_found';
  END IF;

  -- Caller must be an event member or organizer.
  IF NOT EXISTS (
    SELECT 1 FROM event_guests eg
    WHERE eg.event_id = v_event_id
      AND eg.user_id = v_uid
      AND eg.status NOT IN ('left', 'declined')
  ) AND NOT EXISTS (
    SELECT 1 FROM events ev WHERE ev.id = v_event_id AND ev.created_by = v_uid
  ) THEN
    RAISE EXCEPTION 'not_member';
  END IF;

  -- If the target is an app user, prevent double-booking in this activity.
  IF p_user_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM session_queue_entries
    WHERE activity_id = p_activity_id AND user_id = p_user_id
  ) THEN
    RAISE EXCEPTION 'already_in_queue';
  END IF;

  SELECT COUNT(*) INTO v_claimed
  FROM session_queue_entries WHERE activity_id = p_activity_id;

  IF v_claimed >= v_spots THEN
    RAISE EXCEPTION 'queue_full';
  END IF;

  INSERT INTO session_queue_entries
    (activity_id, user_id, display_name, avatar_url, status, queue_position)
  VALUES
    (p_activity_id, p_user_id,
     COALESCE(NULLIF(TRIM(p_display_name), ''), 'Guest'),
     p_avatar_url,
     'playing',
     (v_claimed + 1)::integer);
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_member_to_queue(uuid, uuid, text, text) TO authenticated;
