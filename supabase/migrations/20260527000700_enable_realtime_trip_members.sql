-- Enable Supabase Realtime for trip_members so that InvitationsProvider
-- receives live INSERT/UPDATE events when a new invite arrives.
-- Without this the table is excluded from the supabase_realtime publication
-- and no WebSocket events are broadcast regardless of channel subscriptions.

alter publication supabase_realtime add table public.trip_members;
