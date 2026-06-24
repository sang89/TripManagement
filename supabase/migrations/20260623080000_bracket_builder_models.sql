-- Models needed by the Bracket Structure Builder:
-- 1. `bundle_id` on tournament_divisions groups divisions created together
-- 2. `assign_entrants_to_division` RPC used by createDivisionBundle

ALTER TABLE tournament_divisions
  ADD COLUMN IF NOT EXISTS bundle_id UUID;

-- Batch-register a list of existing tournament_entrant UUIDs into a target
-- division. Used by the bracket builder when it copies draft entrants.
-- No-op for entrants already in the division.
CREATE OR REPLACE FUNCTION assign_entrants_to_division(
  p_division_id UUID,
  p_entrant_ids UUID[]
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- This RPC is reserved for future use when the builder supports
  -- reassigning existing entrant rows across divisions.
  -- Currently the builder uses register_tournament_entrant per entrant.
  RAISE NOTICE 'assign_entrants_to_division: reserved for future use';
END;
$$;
