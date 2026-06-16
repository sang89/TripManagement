-- Chat enhancements: GIF messages + customisable chat backgrounds.
--
-- message_type distinguishes plain text from GIF-URL messages so the
-- Flutter client can render them differently without inspecting content.
--
-- chat_background stores the active preset key chosen by any event member.
-- The Realtime UPDATE handler on the Flutter side propagates it live to every
-- member's device without a page reload.

ALTER TABLE event_messages
  ADD COLUMN IF NOT EXISTS message_type text NOT NULL DEFAULT 'text';

ALTER TABLE event_messages
  DROP CONSTRAINT IF EXISTS event_messages_type_check;

ALTER TABLE event_messages
  ADD CONSTRAINT event_messages_type_check
    CHECK (message_type IN ('text', 'gif'));

ALTER TABLE events
  ADD COLUMN IF NOT EXISTS chat_background text;
