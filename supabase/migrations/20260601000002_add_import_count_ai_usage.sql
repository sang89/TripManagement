-- Add import_count to ai_usage for tracking monthly receipt scan quota.
-- All writes happen from the extract-transactions edge function (service-role).

ALTER TABLE ai_usage
  ADD COLUMN import_count integer NOT NULL DEFAULT 0;
