-- Root-cause fix for cross-app notification contamination.
--
-- The shared `notifications` table is read by PropertyManagement without a
-- type filter, so every TripManagement notification (session_join_request,
-- session_removed, …) also appeared in the PropertyManagement notification
-- centre. Adding an `app` column did not help because PM reads all rows
-- regardless of column values.
--
-- Permanent fix: move all TripManagement notifications to a dedicated
-- `trip_notifications` table that PropertyManagement has no reason to query.
-- The shared `notifications` table is left entirely for PropertyManagement.
--
-- Changes:
--   1. Create trip_notifications (mirrors notifications schema, TM-only).
--   2. RLS: users read / update / delete their own rows.
--   3. insert_trip_notification() – SECURITY DEFINER upsert (same ON CONFLICT
--      logic as the fixed insert_notification so repeated actions refresh the
--      existing row to unread rather than disappearing silently).
--   4. broadcast_trip_notification trigger – fires AFTER INSERT OR UPDATE,
--      skips is_read=true, sends to realtime:trip_notifications_{user_id}.
--   5. Replace ALL trigger functions: every PERFORM public.insert_notification(…)
--      becomes PERFORM public.insert_trip_notification(…).
--   6. Remove the on_notification_inserted trigger from `notifications` that
--      TripManagement added – PM can add its own later if needed; TM no longer
--      writes to that table.

-- ── 1. trip_notifications table ──────────────────────────────────────────────

CREATE TABLE public.trip_notifications (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type         text        NOT NULL,
  title        text        NOT NULL,
  body         text        NOT NULL DEFAULT '',
  reference_id text,
  metadata     jsonb,
  is_read      boolean     NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- Same deduplication index as notifications: one row per (user, type, session/event).
CREATE UNIQUE INDEX trip_notifications_user_type_ref_idx
  ON public.trip_notifications (user_id, type, reference_id)
  WHERE reference_id IS NOT NULL;

CREATE INDEX trip_notifications_user_id_idx
  ON public.trip_notifications (user_id, created_at DESC);

-- ── 2. RLS ───────────────────────────────────────────────────────────────────

ALTER TABLE public.trip_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own trip notifications"
  ON public.trip_notifications FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users update own trip notifications"
  ON public.trip_notifications FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Users delete own trip notifications"
  ON public.trip_notifications FOR DELETE
  USING (user_id = auth.uid());

-- ── 3. insert_trip_notification ───────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.insert_trip_notification(
  p_user_id      uuid,
  p_type         text,
  p_title        text,
  p_body         text,
  p_reference_id text  DEFAULT NULL,
  p_metadata     jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO trip_notifications (user_id, type, title, body, reference_id, metadata)
  VALUES (p_user_id, p_type, p_title, p_body, p_reference_id, p_metadata)
  ON CONFLICT (user_id, type, reference_id) WHERE reference_id IS NOT NULL
  DO UPDATE SET
    title      = EXCLUDED.title,
    body       = EXCLUDED.body,
    metadata   = EXCLUDED.metadata,
    is_read    = false,
    created_at = now();
END;
$$;

-- ── 4. broadcast_trip_notification trigger ───────────────────────────────────

CREATE OR REPLACE FUNCTION public.broadcast_trip_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault
AS $$
DECLARE
  v_key text;
BEGIN
  -- Skip mark-as-read updates; only broadcast new/refreshed unread rows.
  IF NEW.is_read = true THEN RETURN NEW; END IF;

  SELECT decrypted_secret INTO v_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key'
  LIMIT 1;

  IF v_key IS NOT NULL THEN
    PERFORM net.http_post(
      url     := 'https://qgeocaectbdfonrorwco.supabase.co/realtime/v1/api/broadcast',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'apikey',        v_key,
        'Authorization', 'Bearer ' || v_key
      ),
      body    := jsonb_build_object(
        'messages', jsonb_build_array(
          jsonb_build_object(
            'topic',   'realtime:trip_notifications_' || NEW.user_id::text,
            'event',   'new_notification',
            'payload', jsonb_build_object('type', NEW.type)
          )
        )
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_trip_notification_inserted
  AFTER INSERT OR UPDATE ON public.trip_notifications
  FOR EACH ROW EXECUTE FUNCTION public.broadcast_trip_notification();

-- ── 5. Update every trigger function to write to trip_notifications ───────────
--
-- All 10 functions previously called insert_notification() which writes to
-- the shared notifications table. Replace with insert_trip_notification().

-- 5a. handle_new_event_invite
CREATE OR REPLACE FUNCTION public.handle_new_event_invite()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault
AS $$
DECLARE
  v_service_role_key text;
  v_event_title text;
BEGIN
  IF NEW.status = 'pending' AND NEW.user_id IS NOT NULL AND
     (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM 'pending')) THEN

    SELECT title INTO v_event_title FROM events WHERE id = NEW.event_id;
    PERFORM public.insert_trip_notification(
      NEW.user_id,
      'event_invite',
      'New event invitation',
      'You''ve been invited to "' || coalesce(v_event_title, 'an event') || '"',
      NEW.event_id::text
    );

    SELECT decrypted_secret INTO v_service_role_key
    FROM vault.decrypted_secrets WHERE name = 'service_role_key' LIMIT 1;

    IF v_service_role_key IS NOT NULL THEN
      PERFORM net.http_post(
        url     := 'https://qgeocaectbdfonrorwco.supabase.co/functions/v1/send-invite-notification',
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || v_service_role_key
        ),
        body    := jsonb_build_object(
          'guest_id',        NEW.id,
          'event_id',        NEW.event_id,
          'invitee_user_id', NEW.user_id
        )
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- 5b. handle_waitlist_promotion
CREATE OR REPLACE FUNCTION public.handle_waitlist_promotion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault
AS $$
DECLARE
  v_service_role_key text;
  v_event_title text;
BEGIN
  IF OLD.status = 'waitlisted' AND NEW.status = 'going' AND NEW.user_id IS NOT NULL THEN

    SELECT e.title INTO v_event_title
    FROM event_sessions es JOIN events e ON e.id = es.event_id
    WHERE es.id = NEW.session_id;

    PERFORM public.insert_trip_notification(
      NEW.user_id,
      'session_promoted',
      '🎉 You''re in!',
      'Your spot for "' || coalesce(v_event_title, 'the event') || '" is confirmed.',
      NEW.session_id::text
    );

    SELECT decrypted_secret INTO v_service_role_key
    FROM vault.decrypted_secrets WHERE name = 'service_role_key' LIMIT 1;

    IF v_service_role_key IS NOT NULL THEN
      PERFORM net.http_post(
        url     := 'https://qgeocaectbdfonrorwco.supabase.co/functions/v1/send-waitlist-promoted-notification',
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || v_service_role_key
        ),
        body    := jsonb_build_object(
          'roster_id',  NEW.id,
          'session_id', NEW.session_id,
          'user_id',    NEW.user_id
        )
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- 5c. notify_invite_response
CREATE OR REPLACE FUNCTION public.notify_invite_response()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_organizer_id uuid;
  v_event_title  text;
  v_notif_type   text;
  v_notif_title  text;
  v_guest_name   text;
BEGIN
  IF OLD.status = 'pending' AND NEW.status IN ('accepted', 'declined')
     AND NEW.user_id IS NOT NULL THEN

    SELECT created_by, title INTO v_organizer_id, v_event_title
    FROM events WHERE id = NEW.event_id;

    IF v_organizer_id IS NULL OR v_organizer_id = NEW.user_id THEN
      RETURN NEW;
    END IF;

    v_guest_name := coalesce(NEW.display_name, 'Someone');

    IF NEW.status = 'accepted' THEN
      v_notif_type  := 'event_invite_accepted';
      v_notif_title := v_guest_name || ' accepted your invite';
    ELSE
      v_notif_type  := 'event_invite_declined';
      v_notif_title := v_guest_name || ' declined your invite';
    END IF;

    PERFORM public.insert_trip_notification(
      v_organizer_id, v_notif_type, v_notif_title,
      'For "' || coalesce(v_event_title, 'your event') || '"',
      NEW.event_id::text
    );

    PERFORM public.call_push_edge_function(
      v_organizer_id, v_notif_type, v_notif_title,
      'For "' || coalesce(v_event_title, 'your event') || '"',
      jsonb_build_object('event_id', NEW.event_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

-- 5d. notify_member_kicked
CREATE OR REPLACE FUNCTION public.notify_member_kicked()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_title text;
BEGIN
  IF OLD.user_id IS NOT NULL THEN
    SELECT title INTO v_event_title FROM events WHERE id = OLD.event_id;

    PERFORM public.insert_trip_notification(
      OLD.user_id, 'event_kicked',
      'Removed from event',
      'You were removed from "' || coalesce(v_event_title, 'an event') || '"',
      OLD.event_id::text
    );

    PERFORM public.call_push_edge_function(
      OLD.user_id, 'event_kicked',
      'Removed from event',
      'You were removed from "' || coalesce(v_event_title, 'an event') || '"',
      jsonb_build_object('event_id', OLD.event_id)
    );
  END IF;
  RETURN OLD;
END;
$$;

-- 5e. notify_session_join_request
CREATE OR REPLACE FUNCTION public.notify_session_join_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_organizer_id   uuid;
  v_event_title    text;
  v_session_number int;
  v_event_id       uuid;
  v_requester_name text;
BEGIN
  IF NEW.status = 'pending_review' AND NEW.user_id IS NOT NULL THEN
    SELECT e.created_by, e.title, e.id, es.session_number
      INTO v_organizer_id, v_event_title, v_event_id, v_session_number
    FROM event_sessions es JOIN events e ON e.id = es.event_id
    WHERE es.id = NEW.session_id;

    IF v_organizer_id IS NULL THEN RETURN NEW; END IF;

    v_requester_name := coalesce(NEW.display_name, 'Someone');

    PERFORM public.insert_trip_notification(
      v_organizer_id, 'session_join_request',
      'New join request',
      v_requester_name || ' wants to join "' || coalesce(v_event_title, 'your event')
        || '" – Session ' || coalesce(v_session_number::text, '?'),
      NEW.session_id::text,
      jsonb_build_object('event_id', v_event_id)
    );

    PERFORM public.call_push_edge_function(
      v_organizer_id, 'session_join_request',
      'New join request',
      v_requester_name || ' wants to join "' || coalesce(v_event_title, 'your event')
        || '" – Session ' || coalesce(v_session_number::text, '?'),
      jsonb_build_object('session_id', NEW.session_id, 'event_id', v_event_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

-- 5f. notify_session_decision
CREATE OR REPLACE FUNCTION public.notify_session_decision()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_title    text;
  v_event_id       uuid;
  v_session_number int;
  v_notif_type     text;
  v_notif_title    text;
  v_notif_body     text;
BEGIN
  IF OLD.status = 'pending_review' AND NEW.status IN ('going', 'rejected')
     AND NEW.user_id IS NOT NULL THEN

    SELECT e.title, e.id, es.session_number
      INTO v_event_title, v_event_id, v_session_number
    FROM event_sessions es JOIN events e ON e.id = es.event_id
    WHERE es.id = NEW.session_id;

    IF NEW.status = 'going' THEN
      v_notif_type  := 'session_approved';
      v_notif_title := '🎉 Request approved!';
      v_notif_body  := 'You''re confirmed for "' || coalesce(v_event_title, 'the event')
                       || '" – Session ' || coalesce(v_session_number::text, '?');
    ELSE
      v_notif_type  := 'session_rejected';
      v_notif_title := 'Request not approved';
      v_notif_body  := 'Your join request for "' || coalesce(v_event_title, 'the event')
                       || '" was not approved.';
    END IF;

    PERFORM public.insert_trip_notification(
      NEW.user_id, v_notif_type, v_notif_title, v_notif_body,
      NEW.session_id::text,
      jsonb_build_object('event_id', v_event_id)
    );

    PERFORM public.call_push_edge_function(
      NEW.user_id, v_notif_type, v_notif_title, v_notif_body,
      jsonb_build_object('session_id', NEW.session_id, 'event_id', v_event_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

-- 5g. notify_session_demoted
CREATE OR REPLACE FUNCTION public.notify_session_demoted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_title    text;
  v_event_id       uuid;
  v_session_number int;
BEGIN
  IF OLD.status = 'going' AND NEW.status = 'waitlisted' AND NEW.user_id IS NOT NULL THEN
    SELECT e.title, e.id, es.session_number
      INTO v_event_title, v_event_id, v_session_number
    FROM event_sessions es JOIN events e ON e.id = es.event_id
    WHERE es.id = NEW.session_id;

    PERFORM public.insert_trip_notification(
      NEW.user_id, 'session_demoted',
      'Moved to waitlist',
      'You''ve been moved to the waitlist for "' || coalesce(v_event_title, 'the event')
        || '" – Session ' || coalesce(v_session_number::text, '?'),
      NEW.session_id::text,
      jsonb_build_object('event_id', v_event_id)
    );

    PERFORM public.call_push_edge_function(
      NEW.user_id, 'session_demoted',
      'Moved to waitlist',
      'You''ve been moved to the waitlist for "' || coalesce(v_event_title, 'the event')
        || '" – Session ' || coalesce(v_session_number::text, '?'),
      jsonb_build_object('session_id', NEW.session_id, 'event_id', v_event_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

-- 5h. notify_friend_request
CREATE OR REPLACE FUNCTION public.notify_friend_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_requester_name text;
BEGIN
  IF NEW.status = 'pending' THEN
    SELECT full_name INTO v_requester_name
    FROM user_profiles WHERE id = NEW.requester_id;

    PERFORM public.insert_trip_notification(
      NEW.addressee_id, 'friend_request',
      'New friend request',
      coalesce(v_requester_name, 'Someone') || ' sent you a friend request',
      NEW.requester_id::text
    );

    PERFORM public.call_push_edge_function(
      NEW.addressee_id, 'friend_request',
      'New friend request',
      coalesce(v_requester_name, 'Someone') || ' sent you a friend request',
      jsonb_build_object('requester_id', NEW.requester_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

-- 5i. notify_friend_accepted
CREATE OR REPLACE FUNCTION public.notify_friend_accepted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_acceptor_name text;
BEGIN
  IF OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    SELECT full_name INTO v_acceptor_name
    FROM user_profiles WHERE id = NEW.addressee_id;

    PERFORM public.insert_trip_notification(
      NEW.requester_id, 'friend_accepted',
      'Friend request accepted',
      coalesce(v_acceptor_name, 'Someone') || ' accepted your friend request',
      NEW.addressee_id::text
    );

    PERFORM public.call_push_edge_function(
      NEW.requester_id, 'friend_accepted',
      'Friend request accepted',
      coalesce(v_acceptor_name, 'Someone') || ' accepted your friend request',
      jsonb_build_object('addressee_id', NEW.addressee_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

-- 5j. notify_session_removed
CREATE OR REPLACE FUNCTION public.notify_session_removed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_title    text;
  v_event_id       uuid;
  v_session_number int;
BEGIN
  IF NEW.status = 'removed' AND NEW.user_id IS NOT NULL THEN
    SELECT e.title, e.id, es.session_number
      INTO v_event_title, v_event_id, v_session_number
    FROM event_sessions es JOIN events e ON e.id = es.event_id
    WHERE es.id = NEW.session_id;

    PERFORM public.insert_trip_notification(
      NEW.user_id, 'session_removed',
      'Removed from session',
      'You''ve been removed from "' || coalesce(v_event_title, 'the event')
        || '" – Session ' || coalesce(v_session_number::text, '?'),
      NEW.session_id::text,
      jsonb_build_object('event_id', v_event_id)
    );

    PERFORM public.call_push_edge_function(
      NEW.user_id, 'session_removed',
      'Removed from session',
      'You''ve been removed from "' || coalesce(v_event_title, 'the event')
        || '" – Session ' || coalesce(v_session_number::text, '?'),
      jsonb_build_object('session_id', NEW.session_id, 'event_id', v_event_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

-- ── 6. Remove TripManagement's broadcast trigger from the shared notifications
--       table. TM no longer writes there, so the trigger serves no purpose for
--       TM. Leave the table and its data intact for PropertyManagement.

DROP TRIGGER IF EXISTS on_notification_inserted ON public.notifications;

-- Migrate any existing TripManagement notifications from the shared table
-- into trip_notifications so history is preserved.
INSERT INTO public.trip_notifications
  (id, user_id, type, title, body, reference_id, metadata, is_read, created_at)
SELECT id, user_id, type, title, body, reference_id, metadata, is_read, created_at
FROM   public.notifications
WHERE  type IN (
  'event_invite', 'event_invite_accepted', 'event_invite_declined',
  'event_kicked',
  'session_join_request', 'session_approved', 'session_rejected',
  'session_demoted', 'session_promoted', 'session_removed',
  'friend_request', 'friend_accepted'
)
ON CONFLICT DO NOTHING;

-- Remove migrated TripManagement rows from the shared table so PM never sees
-- them again.
DELETE FROM public.notifications
WHERE type IN (
  'event_invite', 'event_invite_accepted', 'event_invite_declined',
  'event_kicked',
  'session_join_request', 'session_approved', 'session_rejected',
  'session_demoted', 'session_promoted', 'session_removed',
  'friend_request', 'friend_accepted'
);
