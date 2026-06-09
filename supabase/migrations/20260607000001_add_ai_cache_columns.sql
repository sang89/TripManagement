-- Add Gemini context-cache tracking columns to ai_usage.
-- The edge function stores the cache name, a hash of the cached content,
-- and the expiry so it can reuse an existing cache instead of recreating it.
alter table ai_usage
  add column if not exists gemini_cache_name       text,
  add column if not exists gemini_cache_hash       text,
  add column if not exists gemini_cache_expires_at timestamptz;
