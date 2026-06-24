-- ─────────────────────────────────────────────────────────────────────────────
-- Tournament customization M9 — reusable rule templates.
--
-- A template is a saved division-config bundle (sport, discipline, format,
-- scoring, entrant_kind, roster/tie settings…) the organizer can reuse across
-- events ("start from template"). Per-user, owner-only.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tournament_templates (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name       text        NOT NULL,
  config     jsonb       NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE tournament_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "owner full access" ON tournament_templates
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_tournament_templates_user ON tournament_templates(user_id);

-- save_tournament_template — create/replace a named template for the caller.
CREATE OR REPLACE FUNCTION save_tournament_template(
  p_name   text,
  p_config jsonb
)
RETURNS SETOF tournament_templates
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_id  uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;

  -- Upsert by (user, name) so re-saving a template updates it.
  SELECT id INTO v_id FROM tournament_templates
  WHERE user_id = v_uid AND name = p_name;

  IF v_id IS NULL THEN
    INSERT INTO tournament_templates (user_id, name, config)
    VALUES (v_uid, p_name, p_config)
    RETURNING id INTO v_id;
  ELSE
    UPDATE tournament_templates SET config = p_config WHERE id = v_id;
  END IF;

  RETURN QUERY SELECT * FROM tournament_templates WHERE id = v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION save_tournament_template(text, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION delete_tournament_template(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM tournament_templates WHERE id = p_id AND user_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION delete_tournament_template(uuid) TO authenticated;
