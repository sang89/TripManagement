-- Trip Photos and Expenses feature.
-- Mirrors the Events pattern (event_photos / event_expenses / event_expense_splits)
-- but scoped to trips and split among trip_members instead of event_guests.

-- ── trip_photos ────────────────────────────────────────────────────────────────

CREATE TABLE trip_photos (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id      uuid        NOT NULL REFERENCES trips ON DELETE CASCADE,
  uploaded_by  uuid        NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  storage_path text        NOT NULL,
  caption      text        NOT NULL DEFAULT '',
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX trip_photos_trip ON trip_photos (trip_id, created_at DESC);

ALTER TABLE trip_photos ENABLE ROW LEVEL SECURITY;

-- ── trip_expenses ──────────────────────────────────────────────────────────────

CREATE TABLE trip_expenses (
  id               uuid           PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id          uuid           NOT NULL REFERENCES trips ON DELETE CASCADE,
  paid_by_user_id  uuid           NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  paid_by_name     text           NOT NULL,
  amount           numeric(10,2)  NOT NULL CHECK (amount > 0),
  description      text           NOT NULL,
  created_at       timestamptz    NOT NULL DEFAULT now()
);

ALTER TABLE trip_expenses ENABLE ROW LEVEL SECURITY;

-- ── trip_expense_splits ────────────────────────────────────────────────────────

CREATE TABLE trip_expense_splits (
  id          uuid           PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id     uuid           NOT NULL REFERENCES trips ON DELETE CASCADE,
  expense_id  uuid           NOT NULL REFERENCES trip_expenses ON DELETE CASCADE,
  member_id   uuid           NOT NULL REFERENCES trip_members ON DELETE CASCADE,
  amount      numeric(10,2)  NOT NULL CHECK (amount > 0),
  settled     boolean        NOT NULL DEFAULT false,
  settled_at  timestamptz
);

ALTER TABLE trip_expense_splits ENABLE ROW LEVEL SECURITY;

-- ── RLS helper ─────────────────────────────────────────────────────────────────

CREATE FUNCTION auth_user_is_trip_member(p_trip_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM trips        WHERE id = p_trip_id AND created_by = auth.uid()
    UNION ALL
    SELECT 1 FROM trip_members WHERE trip_id = p_trip_id AND user_id = auth.uid() AND status = 'accepted'
  );
$$;

REVOKE EXECUTE ON FUNCTION auth_user_is_trip_member(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION auth_user_is_trip_member(uuid) TO authenticated;

-- ── trip_photos RLS ────────────────────────────────────────────────────────────

CREATE POLICY "trip_photos_select" ON trip_photos
  FOR SELECT USING (auth_user_is_trip_member(trip_id));

CREATE POLICY "trip_photos_insert" ON trip_photos
  FOR INSERT WITH CHECK (
    auth_user_is_trip_member(trip_id) AND uploaded_by = auth.uid()
  );

CREATE POLICY "trip_photos_delete" ON trip_photos
  FOR DELETE USING (
    uploaded_by = auth.uid()
    OR (SELECT created_by FROM trips WHERE id = trip_id) = auth.uid()
  );

-- ── trip_expenses RLS ──────────────────────────────────────────────────────────

CREATE POLICY "trip_expenses_select" ON trip_expenses
  FOR SELECT USING (auth_user_is_trip_member(trip_id));

CREATE POLICY "trip_expenses_insert" ON trip_expenses
  FOR INSERT WITH CHECK (
    auth_user_is_trip_member(trip_id) AND paid_by_user_id = auth.uid()
  );

CREATE POLICY "trip_expenses_delete" ON trip_expenses
  FOR DELETE USING (
    paid_by_user_id = auth.uid()
    OR (SELECT created_by FROM trips WHERE id = trip_id) = auth.uid()
  );

-- ── trip_expense_splits RLS ────────────────────────────────────────────────────

CREATE POLICY "trip_expense_splits_select" ON trip_expense_splits
  FOR SELECT USING (auth_user_is_trip_member(trip_id));

CREATE POLICY "trip_expense_splits_insert" ON trip_expense_splits
  FOR INSERT WITH CHECK (auth_user_is_trip_member(trip_id));

CREATE POLICY "trip_expense_splits_update" ON trip_expense_splits
  FOR UPDATE USING (auth_user_is_trip_member(trip_id));

-- ── Realtime ───────────────────────────────────────────────────────────────────

ALTER TABLE trip_photos           REPLICA IDENTITY FULL;
ALTER TABLE trip_expenses         REPLICA IDENTITY DEFAULT;
ALTER TABLE trip_expense_splits   REPLICA IDENTITY DEFAULT;

ALTER PUBLICATION supabase_realtime ADD TABLE trip_photos;
ALTER PUBLICATION supabase_realtime ADD TABLE trip_expenses;
ALTER PUBLICATION supabase_realtime ADD TABLE trip_expense_splits;

-- ── Storage bucket ─────────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public)
VALUES ('trip-photos', 'trip-photos', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "trip_photos_storage_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'trip-photos' AND auth.uid() IS NOT NULL);

CREATE POLICY "trip_photos_storage_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'trip-photos');

CREATE POLICY "trip_photos_storage_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'trip-photos' AND auth.uid() IS NOT NULL);
