-- B4: Document that pending_review entries are intentionally NOT auto-promoted.
-- When a going/waitlisted entry is removed and waitlist auto-promotion fires,
-- only 'waitlisted' rows are promoted. 'pending_review' rows require explicit
-- organizer approval via session_approve_request — this is by design.

COMMENT ON FUNCTION public.session_approve_request(uuid) IS
  'Organizer approves a pending_review signup request, moving it to going.
   pending_review entries are NEVER auto-promoted by cancel/remove triggers —
   they always require explicit organizer action.';

COMMENT ON FUNCTION public.session_reject_request(uuid) IS
  'Organizer rejects (declines) a pending_review signup request and notifies
   the user. The roster row is deleted after notification.
   pending_review entries are NEVER auto-promoted by cancel/remove triggers.';
