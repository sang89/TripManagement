-- Extend Supabase Realtime to trips and trip_stops so every accepted member
-- receives live updates when the organizer edits a trip or modifies stops.
--
-- trip_members was already added in migration 20260527000700.
--
-- REPLICA IDENTITY FULL on trip_stops mirrors the same setting on trip_members
-- (migration 20260527001000): DELETE payloads will include trip_id so the
-- client-side DELETE handler can locate the correct in-memory trip.
--
-- trips does NOT need REPLICA IDENTITY FULL because TripProvider only
-- subscribes to UPDATE events for trips (not DELETE) — the organizer who
-- deletes a trip already handles it locally, and RLS removes the row from
-- other members' view on the next load anyway.

ALTER PUBLICATION supabase_realtime ADD TABLE public.trips;
ALTER PUBLICATION supabase_realtime ADD TABLE public.trip_stops;

ALTER TABLE public.trip_stops REPLICA IDENTITY FULL;
