-- ── Photo rate limit: max 20 uploads per user per event per hour ─────────────
-- Enforced server-side so it cannot be bypassed via direct API calls.

CREATE OR REPLACE FUNCTION check_photo_rate_limit()
RETURNS TRIGGER AS $$
DECLARE
  recent_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO recent_count
  FROM event_photos
  WHERE event_id   = NEW.event_id
    AND uploaded_by = NEW.uploaded_by
    AND created_at  > NOW() - INTERVAL '1 hour';

  IF recent_count >= 20 THEN
    RAISE EXCEPTION 'rate_limit_exceeded';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS enforce_photo_rate_limit ON event_photos;
CREATE TRIGGER enforce_photo_rate_limit
  BEFORE INSERT ON event_photos
  FOR EACH ROW EXECUTE FUNCTION check_photo_rate_limit();

-- ── Photo cap per event: 100 (free) / 500 (pro/admin/trial) ─────────────────
-- Cap is based on the event organizer's subscription tier.

CREATE OR REPLACE FUNCTION check_event_photo_cap()
RETURNS TRIGGER AS $$
DECLARE
  total_count  INTEGER;
  organizer_id uuid;
  is_pro       boolean;
  photo_cap    INTEGER;
BEGIN
  SELECT created_by INTO organizer_id
  FROM events
  WHERE id = NEW.event_id;

  SELECT EXISTS (
    SELECT 1 FROM user_subscriptions
    WHERE user_id = organizer_id
      AND app     = 'trip_management'
      AND (
        tier IN ('pro', 'admin')
        OR (trial_ends_at IS NOT NULL AND trial_ends_at > NOW())
      )
  ) INTO is_pro;

  photo_cap := CASE WHEN is_pro THEN 500 ELSE 100 END;

  SELECT COUNT(*) INTO total_count
  FROM event_photos
  WHERE event_id = NEW.event_id;

  IF total_count >= photo_cap THEN
    RAISE EXCEPTION 'photo_cap_exceeded';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS enforce_event_photo_cap ON event_photos;
CREATE TRIGGER enforce_event_photo_cap
  BEFORE INSERT ON event_photos
  FOR EACH ROW EXECUTE FUNCTION check_event_photo_cap();
