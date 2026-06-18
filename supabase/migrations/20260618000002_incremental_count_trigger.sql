-- ─────────────────────────────────────────────────────────────────────────────
-- Replace COUNT-scan count trigger with incremental arithmetic.
--
-- Original trigger ran two full-table COUNT scans on session_queue_entries for
-- every INSERT, UPDATE, or DELETE on that table.  At 100 entries per queue, a
-- single leave event (DELETE + any cascading updates) could trigger 200+
-- unnecessary table scans.
--
-- New trigger uses arithmetic deltas — O(1) regardless of queue size:
--   INSERT new_status  → +1 to the matching counter
--   DELETE old_status  → -1 from the matching counter
--   UPDATE status change → swap: -1 old, +1 new  (no-op when status unchanged)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public._update_queue_activity_counts()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_activity_id uuid;
BEGIN
  v_activity_id := COALESCE(NEW.activity_id, OLD.activity_id);

  UPDATE session_queue_activities SET
    playing_count = playing_count
      + (CASE WHEN TG_OP <> 'DELETE' AND NEW.status = 'playing' THEN 1 ELSE 0 END)
      - (CASE WHEN TG_OP <> 'INSERT' AND OLD.status = 'playing' THEN 1 ELSE 0 END),
    waiting_count = waiting_count
      + (CASE WHEN TG_OP <> 'DELETE' AND NEW.status = 'waiting' THEN 1 ELSE 0 END)
      - (CASE WHEN TG_OP <> 'INSERT' AND OLD.status = 'waiting' THEN 1 ELSE 0 END)
  WHERE id = v_activity_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Trigger definition is unchanged — just the function body changes.
-- trg_queue_entry_counts on session_queue_entries already calls this function.
