-- Extend event_messages.message_type to support chat image attachments.
-- Images are uploaded to the event-photos bucket under {event_id}/chat/ and
-- their public URL is stored in content, identical to the gif flow.

ALTER TABLE event_messages DROP CONSTRAINT IF EXISTS event_messages_type_check;

ALTER TABLE event_messages
  ADD CONSTRAINT event_messages_type_check
    CHECK (message_type IN ('text', 'gif', 'image'));
