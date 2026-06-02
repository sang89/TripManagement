-- Add per-user opt-out for @mention push notifications.
-- The edge function checks this before sending FCM to any mentioned user.

ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS mention_notifications_enabled boolean NOT NULL DEFAULT true;
