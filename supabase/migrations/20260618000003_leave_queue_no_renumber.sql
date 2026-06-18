-- ─────────────────────────────────────────────────────────────────────────────
-- Remove O(N) position renumbering from leave_queue.
--
-- The original leave_queue renumbered ALL remaining waiting entries after a
-- DELETE — closing the gap so positions stayed contiguous (1, 2, 3…).  At 100
-- members this issued 99 individual UPDATE statements, each one firing the
-- count trigger.  The end result was effectively O(N²) DB work per leave event.
--
-- Renumbering is not needed:
--   • The client sorts entries by queue_position ASC and renders by list index,
--     so gaps (e.g. 1, 3, 4) produce the same UI as contiguous positions.
--   • The capacity check in join_queue uses COUNT (not MAX), so gaps do not
--     affect overbooking protection.
--   • The "kick count" preview in the setup form has been updated to use
--     (entries.length - newSpots).clamp(0, …) instead of position comparisons.
--
-- After this migration, queue_position values may have gaps but are always
-- monotonically increasing, ensuring stable sort order.
-- ─────────────────────────────────────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.leave_queue(uuid);

CREATE FUNCTION public.leave_queue(p_entry_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid         uuid := auth.uid();
  v_activity_id uuid;
  v_event_id    uuid;
BEGIN
  SELECT e.activity_id, a.event_id
  INTO v_activity_id, v_event_id
  FROM session_queue_entries e
  JOIN session_queue_activities a ON a.id = e.activity_id
  WHERE e.id = p_entry_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found';
  END IF;

  -- Must own the row or be the event organizer.
  IF NOT EXISTS (SELECT 1 FROM session_queue_entries WHERE id = p_entry_id AND user_id = v_uid)
  AND NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = v_uid)
  THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  DELETE FROM session_queue_entries WHERE id = p_entry_id;
  -- No renumbering: the client sorts by queue_position ASC and renders by index.
  -- Gaps are invisible to users and position values remain monotonically ordered.
END;
$$;

GRANT EXECUTE ON FUNCTION public.leave_queue(uuid) TO authenticated;
