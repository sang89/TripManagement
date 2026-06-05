-- Add optional RSVP note that guests can attach when they RSVP.
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS rsvp_note text;
