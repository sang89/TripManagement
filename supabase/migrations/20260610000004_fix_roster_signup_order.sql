-- Fix FIFO ordering on event_session_roster.
--
-- Root cause: rows created before signup_order was tracked (or via manual
-- insertion) have signup_order = NULL.  rsvp_session computes
-- COALESCE(MAX(signup_order), 0) + 1, so the first authenticated user to join
-- AFTER the NULLs gets order = 1 and appears at the top of the waitlist,
-- displacing people who actually joined earlier.
--
-- Fix: reassign signup_order for every row in the table using ROW_NUMBER()
-- ordered by signed_up_at ASC (then id for determinism).  This preserves the
-- real join sequence and leaves no NULLs for future rsvp_session calls to
-- misinterpret.

WITH reordered AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY session_id
           ORDER BY signed_up_at ASC NULLS LAST, id ASC
         ) AS new_order
  FROM event_session_roster
)
UPDATE event_session_roster esr
SET    signup_order = r.new_order
FROM   reordered r
WHERE  esr.id = r.id;
