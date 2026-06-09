-- Birthday event features
-- Adds birthday-specific columns to events and creates 5 new tables:
--   event_wishlist_items, event_gift_pools, event_gift_pledges,
--   event_predictions, event_wishes, event_toasts

-- 1. New columns on events table
ALTER TABLE events
  ADD COLUMN IF NOT EXISTS honoree_name            text,
  ADD COLUMN IF NOT EXISTS birth_year              integer,
  ADD COLUMN IF NOT EXISTS predictions_revealed_at timestamptz,
  ADD COLUMN IF NOT EXISTS wishes_revealed_at      timestamptz;

-- 2. Wishlist items (claimable gift list)
CREATE TABLE event_wishlist_items (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id        uuid        NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  label           text        NOT NULL,
  price_range     text,
  link            text,
  created_by      uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at      timestamptz NOT NULL DEFAULT now(),
  claimed_by      uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  claimed_by_name text,
  claimed_at      timestamptz,
  is_received     bool        NOT NULL DEFAULT false
);
ALTER TABLE event_wishlist_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "wishlist_select" ON event_wishlist_items
  FOR SELECT USING (auth_user_is_event_member(event_id));

CREATE POLICY "wishlist_insert" ON event_wishlist_items
  FOR INSERT WITH CHECK (
    auth.uid() = created_by AND auth_user_is_event_member(event_id)
  );

CREATE POLICY "wishlist_update" ON event_wishlist_items
  FOR UPDATE USING (auth_user_is_event_member(event_id))
  WITH CHECK (auth_user_is_event_member(event_id));

CREATE POLICY "wishlist_delete" ON event_wishlist_items
  FOR DELETE USING (
    auth.uid() = created_by
    OR EXISTS (SELECT 1 FROM events WHERE id = event_id AND created_by = auth.uid())
  );

-- 3. Group gift pools
CREATE TABLE event_gift_pools (
  id            uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id      uuid          NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  gift_name     text          NOT NULL,
  target_amount numeric(10,2) NOT NULL,
  created_by    uuid          NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at    timestamptz   NOT NULL DEFAULT now()
);
ALTER TABLE event_gift_pools ENABLE ROW LEVEL SECURITY;

CREATE POLICY "gift_pools_select" ON event_gift_pools
  FOR SELECT USING (auth_user_is_event_member(event_id));

CREATE POLICY "gift_pools_insert" ON event_gift_pools
  FOR INSERT WITH CHECK (
    auth.uid() = created_by
    AND EXISTS (SELECT 1 FROM events WHERE id = event_id AND created_by = auth.uid())
  );

CREATE POLICY "gift_pools_delete" ON event_gift_pools
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM events WHERE id = event_id AND created_by = auth.uid())
  );

-- 4. Gift pledges
CREATE TABLE event_gift_pledges (
  id              uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  pool_id         uuid          NOT NULL REFERENCES event_gift_pools(id) ON DELETE CASCADE,
  pledged_by      uuid          NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pledged_by_name text          NOT NULL,
  amount          numeric(10,2) NOT NULL,
  pledged_at      timestamptz   NOT NULL DEFAULT now()
);
ALTER TABLE event_gift_pledges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "gift_pledges_select" ON event_gift_pledges
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM event_gift_pools gp
      WHERE gp.id = pool_id AND auth_user_is_event_member(gp.event_id)
    )
  );

CREATE POLICY "gift_pledges_insert" ON event_gift_pledges
  FOR INSERT WITH CHECK (
    auth.uid() = pledged_by
    AND EXISTS (
      SELECT 1 FROM event_gift_pools gp
      WHERE gp.id = pool_id AND auth_user_is_event_member(gp.event_id)
    )
  );

CREATE POLICY "gift_pledges_delete" ON event_gift_pledges
  FOR DELETE USING (
    auth.uid() = pledged_by
    OR EXISTS (
      SELECT 1 FROM event_gift_pools gp
      JOIN events e ON e.id = gp.event_id
      WHERE gp.id = pool_id AND e.created_by = auth.uid()
    )
  );

-- 5. Birthday predictions (sealed until event date)
CREATE TABLE event_predictions (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id          uuid        NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  submitted_by      uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  submitted_by_name text        NOT NULL,
  prediction_text   text        NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE event_predictions ENABLE ROW LEVEL SECURITY;

-- Visible only after reveal, or to submitter, or to organizer.
CREATE POLICY "predictions_select" ON event_predictions
  FOR SELECT USING (
    submitted_by = auth.uid()
    OR EXISTS (SELECT 1 FROM events WHERE id = event_id AND created_by = auth.uid())
    OR EXISTS (SELECT 1 FROM events WHERE id = event_id AND predictions_revealed_at IS NOT NULL)
  );

CREATE POLICY "predictions_insert" ON event_predictions
  FOR INSERT WITH CHECK (
    auth.uid() = submitted_by AND auth_user_is_event_member(event_id)
  );

CREATE POLICY "predictions_delete" ON event_predictions
  FOR DELETE USING (
    auth.uid() = submitted_by
    OR EXISTS (SELECT 1 FROM events WHERE id = event_id AND created_by = auth.uid())
  );

-- 6. Candle wishes (secret until honoree reveals them)
CREATE TABLE event_wishes (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id          uuid        NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  submitted_by      uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  submitted_by_name text        NOT NULL,
  wish_text         text        NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE event_wishes ENABLE ROW LEVEL SECURITY;

-- Visible only after reveal, or to submitter, or to organizer.
CREATE POLICY "wishes_select" ON event_wishes
  FOR SELECT USING (
    submitted_by = auth.uid()
    OR EXISTS (SELECT 1 FROM events WHERE id = event_id AND created_by = auth.uid())
    OR EXISTS (SELECT 1 FROM events WHERE id = event_id AND wishes_revealed_at IS NOT NULL)
  );

CREATE POLICY "wishes_insert" ON event_wishes
  FOR INSERT WITH CHECK (
    auth.uid() = submitted_by AND auth_user_is_event_member(event_id)
  );

CREATE POLICY "wishes_delete" ON event_wishes
  FOR DELETE USING (
    auth.uid() = submitted_by
    OR EXISTS (SELECT 1 FROM events WHERE id = event_id AND created_by = auth.uid())
  );

-- 7. Toast / speech submissions
CREATE TABLE event_toasts (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id          uuid        NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  submitted_by      uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  submitted_by_name text        NOT NULL,
  toast_text        text        NOT NULL,
  toast_type        text        NOT NULL DEFAULT 'sweet',
  sort_order        int         NOT NULL DEFAULT 0,
  created_at        timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE event_toasts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "toasts_select" ON event_toasts
  FOR SELECT USING (auth_user_is_event_member(event_id));

CREATE POLICY "toasts_insert" ON event_toasts
  FOR INSERT WITH CHECK (
    auth.uid() = submitted_by AND auth_user_is_event_member(event_id)
  );

CREATE POLICY "toasts_update" ON event_toasts
  FOR UPDATE USING (
    auth.uid() = submitted_by
    OR EXISTS (SELECT 1 FROM events WHERE id = event_id AND created_by = auth.uid())
  )
  WITH CHECK (
    auth.uid() = submitted_by
    OR EXISTS (SELECT 1 FROM events WHERE id = event_id AND created_by = auth.uid())
  );

CREATE POLICY "toasts_delete" ON event_toasts
  FOR DELETE USING (
    auth.uid() = submitted_by
    OR EXISTS (SELECT 1 FROM events WHERE id = event_id AND created_by = auth.uid())
  );

-- 8. Update create_event RPC to accept birthday fields.
CREATE OR REPLACE FUNCTION create_event(
  p_title            text,
  p_description      text,
  p_location         text,
  p_start_at         timestamptz,
  p_location_lat     double precision DEFAULT NULL,
  p_location_lng     double precision DEFAULT NULL,
  p_end_at           timestamptz      DEFAULT NULL,
  p_capacity         integer          DEFAULT NULL,
  p_event_type       event_type       DEFAULT 'social',
  p_start_location   text             DEFAULT NULL,
  p_start_lat        double precision DEFAULT NULL,
  p_start_lng        double precision DEFAULT NULL,
  p_budget_per_head  numeric(10,2)    DEFAULT NULL,
  p_cuisine_tags     text[]           DEFAULT '{}',
  p_rsvp_deadline    timestamptz      DEFAULT NULL,
  p_vibe             text             DEFAULT NULL,
  p_honoree_name     text             DEFAULT NULL,
  p_birth_year       integer          DEFAULT NULL
)
RETURNS TABLE (
  id                       uuid,
  created_by               uuid,
  title                    text,
  description              text,
  location                 text,
  location_lat             double precision,
  location_lng             double precision,
  start_at                 timestamptz,
  end_at                   timestamptz,
  capacity                 integer,
  invite_code              uuid,
  created_at               timestamptz,
  updated_at               timestamptz,
  event_type               event_type,
  start_location           text,
  start_lat                double precision,
  start_lng                double precision,
  budget_per_head          numeric,
  cuisine_tags             text[],
  rsvp_deadline            timestamptz,
  vibe                     text,
  honoree_name             text,
  birth_year               integer,
  predictions_revealed_at  timestamptz,
  wishes_revealed_at       timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated'
      USING HINT = 'You must be signed in to create an event.';
  END IF;

  RETURN QUERY
    INSERT INTO events (
      created_by, title, description, location,
      location_lat, location_lng,
      start_at, end_at, capacity,
      event_type, start_location, start_lat, start_lng,
      budget_per_head, cuisine_tags, rsvp_deadline, vibe,
      honoree_name, birth_year
    )
    VALUES (
      v_uid, p_title, p_description, p_location,
      p_location_lat, p_location_lng,
      p_start_at, p_end_at, p_capacity,
      p_event_type, p_start_location, p_start_lat, p_start_lng,
      p_budget_per_head, p_cuisine_tags, p_rsvp_deadline, p_vibe,
      p_honoree_name, p_birth_year
    )
    RETURNING
      events.id, events.created_by, events.title, events.description,
      events.location, events.location_lat, events.location_lng,
      events.start_at, events.end_at, events.capacity, events.invite_code,
      events.created_at, events.updated_at,
      events.event_type, events.start_location, events.start_lat, events.start_lng,
      events.budget_per_head, events.cuisine_tags, events.rsvp_deadline, events.vibe,
      events.honoree_name, events.birth_year,
      events.predictions_revealed_at, events.wishes_revealed_at;
END;
$$;
