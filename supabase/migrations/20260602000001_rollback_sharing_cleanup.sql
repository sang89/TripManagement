-- Finish the sharing rollback: remove account_shares table and helper functions
-- that were not cleaned up when 20260602000000 failed mid-run.
drop table if exists account_shares;
drop function if exists public.has_share_write(uuid, text);
drop function if exists public.has_share_read(uuid, text);
drop function if exists public.auth_email();
