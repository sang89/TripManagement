-- Drop the old create_event signature (without birthday params) to resolve
-- the PGRST203 "Multiple Choices" ambiguity introduced when the birthday
-- migration used CREATE OR REPLACE with extra parameters.
DROP FUNCTION IF EXISTS public.create_event(
  text, text, text, timestamptz,
  double precision, double precision,
  timestamptz, integer, event_type,
  text, double precision, double precision,
  numeric, text[], timestamptz, text
);
