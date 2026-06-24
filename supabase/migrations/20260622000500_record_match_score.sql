-- ─────────────────────────────────────────────────────────────────────────────
-- record_match_score (M4)
--
-- Organizer records the per-game scores for a match. The RPC derives winners
-- server-side (per-game winner = higher score; match winner = more games won),
-- marks the match completed, auto-advances the winner into the next match's
-- slot, and frees the court. Re-recording is allowed only while the downstream
-- match has not yet completed.
--
--   p_games — array of { game_number, entrant1_score, entrant2_score }
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION record_match_score(
  p_match_id uuid,
  p_games    jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match     tournament_matches%ROWTYPE;
  v_event_id  uuid;
  v_elem      jsonb;
  v_s1        int;
  v_s2        int;
  v_g1        int := 0;  -- games won by entrant1
  v_g2        int := 0;  -- games won by entrant2
  v_winner    uuid;
  v_next      tournament_matches%ROWTYPE;
BEGIN
  SELECT * INTO v_match FROM tournament_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'match_not_found'; END IF;

  SELECT e.id INTO v_event_id
  FROM tournament_divisions d JOIN events e ON e.id = d.event_id
  WHERE d.id = v_match.division_id;

  IF NOT EXISTS (SELECT 1 FROM events WHERE id = v_event_id AND created_by = auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF v_match.status = 'bye' THEN
    RAISE EXCEPTION 'cannot_score_bye';
  END IF;

  IF v_match.entrant1_id IS NULL OR v_match.entrant2_id IS NULL THEN
    RAISE EXCEPTION 'match_not_ready';
  END IF;

  -- Block re-editing if the winner already advanced and that next match is done.
  IF v_match.next_match_id IS NOT NULL THEN
    SELECT * INTO v_next FROM tournament_matches WHERE id = v_match.next_match_id;
    IF FOUND AND v_next.status = 'completed' THEN
      RAISE EXCEPTION 'downstream_match_played';
    END IF;
  END IF;

  -- Replace any existing games.
  DELETE FROM tournament_match_games WHERE match_id = p_match_id;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_games) LOOP
    v_s1 := (v_elem ->> 'entrant1_score')::int;
    v_s2 := (v_elem ->> 'entrant2_score')::int;
    IF v_s1 = v_s2 THEN
      RAISE EXCEPTION 'invalid_game_score';
    END IF;

    IF v_s1 > v_s2 THEN
      v_g1 := v_g1 + 1;
    ELSE
      v_g2 := v_g2 + 1;
    END IF;

    INSERT INTO tournament_match_games (
      match_id, game_number, entrant1_score, entrant2_score, winner_entrant_id
    ) VALUES (
      p_match_id,
      (v_elem ->> 'game_number')::int,
      v_s1, v_s2,
      CASE WHEN v_s1 > v_s2 THEN v_match.entrant1_id ELSE v_match.entrant2_id END
    );
  END LOOP;

  IF v_g1 = v_g2 THEN
    RAISE EXCEPTION 'no_decisive_winner';
  END IF;

  v_winner := CASE WHEN v_g1 > v_g2 THEN v_match.entrant1_id ELSE v_match.entrant2_id END;

  UPDATE tournament_matches
    SET winner_entrant_id = v_winner, status = 'completed'
    WHERE id = p_match_id;

  -- Auto-advance the winner into the next match's slot.
  IF v_match.next_match_id IS NOT NULL AND v_match.next_match_slot IS NOT NULL THEN
    IF v_match.next_match_slot = 1 THEN
      UPDATE tournament_matches SET entrant1_id = v_winner WHERE id = v_match.next_match_id;
    ELSE
      UPDATE tournament_matches SET entrant2_id = v_winner WHERE id = v_match.next_match_id;
    END IF;
    -- Promote the next match to 'scheduled' once both slots are filled.
    UPDATE tournament_matches
      SET status = 'scheduled'
      WHERE id = v_match.next_match_id
        AND status = 'pending'
        AND entrant1_id IS NOT NULL
        AND entrant2_id IS NOT NULL;
  END IF;

  -- Free the court this match occupied.
  IF v_match.court_id IS NOT NULL THEN
    UPDATE tournament_courts
      SET status = 'available', current_match_id = NULL
      WHERE id = v_match.court_id AND current_match_id = p_match_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION record_match_score(uuid, jsonb) TO authenticated;
