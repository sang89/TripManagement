-- ─────────────────────────────────────────────────────────────────────────────
-- Add is_active status to event_sessions.
--
-- Rules:
--   • Default: false (inactive).
--   • Auto-activates when start_at arrives (handled client-side via timer +
--     this RPC; all connected clients see the change via Realtime).
--   • Auto-deactivates when end_at passes.
--   • Organizer can manually force active or inactive at any time.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE event_sessions
  ADD COLUMN is_active boolean NOT NULL DEFAULT false;

-- ─── RPC: organizer or client-side timer toggles a session's active state ─────

CREATE FUNCTION public.toggle_session_active(
  p_session_id uuid,
  p_active     boolean
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_event_id uuid;
BEGIN
  SELECT event_id INTO v_event_id FROM event_sessions WHERE id = p_session_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'session_not_found';
  END IF;

  -- Only the event organizer (or a member on behalf of the timer — we validate
  -- organizer for manual calls; the client-side timer also calls this as the
  -- organizer's authenticated session).
  IF NOT EXISTS (
    SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

  UPDATE event_sessions SET is_active = p_active WHERE id = p_session_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_session_active(uuid, boolean) TO authenticated;
