-- ─────────────────────────────────────────────────────────────────────────────
-- Add is_active_override to event_sessions.
--
-- When an organizer manually toggles a session active/inactive, this flag is
-- set to true. The client-side auto-timer skips sessions that have been
-- manually overridden, so the organizer's choice is always respected.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE event_sessions
  ADD COLUMN is_active_override boolean NOT NULL DEFAULT false;

-- Re-create toggle_session_active to also set the override flag.
CREATE OR REPLACE FUNCTION public.toggle_session_active(
  p_session_id uuid,
  p_active     boolean
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_event_id uuid;
BEGIN
  SELECT event_id INTO v_event_id FROM event_sessions WHERE id = p_session_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'session_not_found'; END IF;
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;
  -- Set both is_active and is_active_override so the auto-timer won't revert.
  UPDATE event_sessions
  SET is_active = p_active, is_active_override = true
  WHERE id = p_session_id;
END;
$$;

-- New RPC called only by the client-side auto-timer.
-- Only updates is_active when the organizer has NOT manually overridden the session.
CREATE FUNCTION public.auto_session_active(
  p_session_id uuid,
  p_active     boolean
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_event_id uuid;
BEGIN
  SELECT event_id INTO v_event_id FROM event_sessions WHERE id = p_session_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'session_not_found'; END IF;
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;
  -- Only update if the organizer has not taken manual control.
  UPDATE event_sessions
  SET is_active = p_active
  WHERE id = p_session_id AND is_active_override = false;
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_session_active(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.auto_session_active(uuid, boolean) TO authenticated;
