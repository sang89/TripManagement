-- Add per-app isolation to user_subscriptions and ai_usage.
-- Existing rows (PropertyManagement) get app = 'property_management'.

-- ── user_subscriptions ────────────────────────────────────────────────────────
ALTER TABLE user_subscriptions
  ADD COLUMN app text NOT NULL DEFAULT 'property_management';

-- Swap unique constraint from (user_id) → (user_id, app)
ALTER TABLE user_subscriptions
  DROP CONSTRAINT user_subscriptions_user_id_key;

ALTER TABLE user_subscriptions
  ADD CONSTRAINT user_subscriptions_user_id_app_key UNIQUE (user_id, app);

-- ── ai_usage ──────────────────────────────────────────────────────────────────
ALTER TABLE ai_usage
  ADD COLUMN app text NOT NULL DEFAULT 'property_management';

ALTER TABLE ai_usage
  DROP CONSTRAINT ai_usage_user_id_key;

ALTER TABLE ai_usage
  ADD CONSTRAINT ai_usage_user_id_app_key UNIQUE (user_id, app);
