-- ─────────────────────────────────────────────────────────────────────────────
-- Fix add_member_to_queue and add_members_to_queue: use MAX(queue_position)+1
-- for position assignment instead of COUNT(*)+1.
--
-- Root cause (same as join_queue before 20260618000001):
--   After leaves, queue_position values have gaps (e.g. 1, 2, 7).
--   COUNT(*) = 3, so the next member was assigned position 4 — which sorts
--   BEFORE position 7, displacing the existing player at slot 3 down to slot 4.
--   The client sorts entries by queue_position ASC and renders by list index,
--   so any position lower than an existing entry causes a visible "swap".
--
-- Fix: use COALESCE(MAX(queue_position), 0) + 1, which always appends after
-- the last entry regardless of gaps. COUNT(*) is kept only for the capacity
-- check (it is unaffected by position gaps).
--
-- Also adds FOR UPDATE on the activity row in add_member_to_queue to match
-- the serialization guard already present in join_queue and add_members_to_queue.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── add_member_to_queue ──────────────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.add_member_to_queue(uuid, uuid, text, text);

CREATE FUNCTION public.add_member_to_queue(
  p_activity_id  uuid,
  p_user_id      uuid,
  p_display_name text,
  p_avatar_url   text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid              uuid    := auth.uid();
  v_event_id         uuid;
  v_session_id       uuid;
  v_spots            integer;
  v_claimed          bigint;
  v_max_pos          integer;
  v_allow_duplicates boolean;
BEGIN
  -- Lock activity row to serialise concurrent adds.
  SELECT es.event_id, a.session_id, a.players_per_round, a.allow_duplicates
  INTO v_event_id, v_session_id, v_spots, v_allow_duplicates
  FROM session_queue_activities a
  JOIN event_sessions es ON es.id = a.session_id
  WHERE a.id = p_activity_id
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'activity_not_found'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM event_guests eg
    WHERE eg.event_id = v_event_id AND eg.user_id = v_uid AND eg.status NOT IN ('left','declined')
  ) AND NOT EXISTS (
    SELECT 1 FROM events ev WHERE ev.id = v_event_id AND ev.created_by = v_uid
  ) THEN
    RAISE EXCEPTION 'not_member';
  END IF;

  IF p_user_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM session_queue_entries WHERE activity_id = p_activity_id AND user_id = p_user_id
    ) THEN
      RAISE EXCEPTION 'already_in_queue';
    END IF;

    IF NOT v_allow_duplicates AND EXISTS (
      SELECT 1 FROM session_queue_entries sqe
      JOIN session_queue_activities sqa ON sqa.id = sqe.activity_id
      WHERE sqa.session_id = v_session_id
        AND sqe.user_id = p_user_id
        AND sqe.activity_id <> p_activity_id
    ) THEN
      RAISE EXCEPTION 'already_in_queue';
    END IF;
  END IF;

  -- Capacity check uses COUNT (unaffected by position gaps).
  SELECT COUNT(*) INTO v_claimed
  FROM session_queue_entries WHERE activity_id = p_activity_id;

  IF v_claimed >= v_spots THEN RAISE EXCEPTION 'queue_full'; END IF;

  -- Position uses MAX+1 to always append after the last entry, even with gaps.
  SELECT COALESCE(MAX(queue_position), 0) INTO v_max_pos
  FROM session_queue_entries WHERE activity_id = p_activity_id;

  INSERT INTO session_queue_entries
    (activity_id, user_id, display_name, avatar_url, status, queue_position)
  VALUES
    (p_activity_id, p_user_id,
     COALESCE(NULLIF(TRIM(p_display_name), ''), 'Guest'),
     p_avatar_url, 'playing', v_max_pos + 1);
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_member_to_queue(uuid, uuid, text, text) TO authenticated;

-- ── add_members_to_queue ─────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.add_members_to_queue(
  p_activity_id uuid,
  p_members      jsonb
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid       uuid    := auth.uid();
  v_event_id  uuid;
  v_spots     integer;
  v_claimed   bigint;
  v_pos       integer;
  v_member    jsonb;
  v_user_id   uuid;
BEGIN
  SELECT a.event_id, a.players_per_round
    INTO v_event_id, v_spots
    FROM session_queue_activities a
   WHERE a.id = p_activity_id
     FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'activity_not_found'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM event_guests
     WHERE event_id = v_event_id AND user_id = v_uid
       AND status NOT IN ('left', 'declined')
  ) AND NOT EXISTS (
    SELECT 1 FROM events WHERE id = v_event_id AND created_by = v_uid
  ) THEN
    RAISE EXCEPTION 'not_member';
  END IF;

  -- Capacity check uses COUNT (unaffected by gaps).
  SELECT COUNT(*) INTO v_claimed
    FROM session_queue_entries WHERE activity_id = p_activity_id;

  IF v_spots - v_claimed < jsonb_array_length(p_members) THEN
    RAISE EXCEPTION 'queue_full';
  END IF;

  -- Start position at MAX to always append after existing entries.
  SELECT COALESCE(MAX(queue_position), 0) INTO v_pos
    FROM session_queue_entries WHERE activity_id = p_activity_id;

  FOR v_member IN SELECT * FROM jsonb_array_elements(p_members) LOOP
    v_user_id := CASE
      WHEN v_member->>'user_id' IS NULL OR v_member->>'user_id' = 'null' THEN NULL
      ELSE (v_member->>'user_id')::uuid
    END;

    IF v_user_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM session_queue_entries
       WHERE activity_id = p_activity_id AND user_id = v_user_id
    ) THEN
      CONTINUE;
    END IF;

    v_pos := v_pos + 1;
    INSERT INTO session_queue_entries
      (activity_id, user_id, display_name, avatar_url, status, queue_position)
    VALUES (
      p_activity_id,
      v_user_id,
      COALESCE(NULLIF(TRIM(v_member->>'display_name'), ''), 'Guest'),
      NULLIF(v_member->>'avatar_url', 'null'),
      'playing',
      v_pos
    );
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_members_to_queue(uuid, jsonb) TO authenticated;
