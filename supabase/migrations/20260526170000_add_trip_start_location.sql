-- Add optional start location to trips.
-- The start is the departure point for the route: start → stops → destination.

alter table trips
  add column if not exists start_location text,
  add column if not exists start_lat      double precision,
  add column if not exists start_lng      double precision;
