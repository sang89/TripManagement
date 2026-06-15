-- Notification system: expand type CHECK, add in-app notification inserts to
-- existing triggers, and add new triggers for all remaining notification types.

-- ── 1. Add notifications to Realtime so the Flutter provider receives live updates ──

ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- ── 2. Drop the old narrow type CHECK constraint ─────────────────────────────
-- The table is shared with PropertyManagement and may already hold rows with
-- types outside the original two-value list. Drop the constraint; application
-- code (SECURITY DEFINER triggers) enforces valid types at write time.

DO $$
DECLARE
  v_conname text;
BEGIN
  SELECT conname INTO v_conname
  FROM pg_constraint
  WHERE conrelid = 'public.notifications'::regclass
    AND contype = 'c'
    AND pg_get_constraintdef(oid) LIKE '%lease_expiry%';

  IF v_conname IS NOT NULL THEN
    EXECUTE 'ALTER TABLE notifications DROP CONSTRAINT ' || quote_ident(v_conname);
  END IF;
END;
$$;

-- ── 3. Helper: insert_notification ───────────────────────────────────────────
-- SECURITY DEFINER so any trigger can write a notification for any user,
-- bypassing the user-scoped RLS policy on notifications.

CREATE OR REPLACE FUNCTION public.insert_notification(
  p_user_id    uuid,
  p_type       text,
  p_title      text,
  p_body       text,
  p_reference_id text DEFAULT NULL,
  p_metadata   jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO notifications (user_id, type, title, body, reference_id, metadata)
  VALUES (p_user_id, p_type, p_title, p_body, p_reference_id, p_metadata)
  ON CONFLICT DO NOTHING;
END;
$$;

-- ── 4. Helper: call_push_edge_function ───────────────────────────────────────
-- Calls the generic send-push-notification Edge Function via pg_net.
-- Reads the service role key from vault (same pattern as existing triggers).

CREATE OR REPLACE FUNCTION public.call_push_edge_function(
  p_user_id uuid,
  p_type    text,
  p_title   text,
  p_body    text,
  p_data    jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault
AS $$
DECLARE
  v_service_role_key text;
BEGIN
  SELECT decrypted_secret INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key'
  LIMIT 1;

  IF v_service_role_key IS NOT NULL THEN
    PERFORM net.http_post(
      url     := 'https://qgeocaectbdfonrorwco.supabase.co'
                 || '/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_service_role_key
      ),
      body    := jsonb_build_object(
        'user_id', p_user_id,
        'type',    p_type,
        'title',   p_title,
        'body',    p_body,
        'data',    p_data
      )
    );
  END IF;
END;
$$;

-- ── 5. Update handle_new_event_invite to also write an in-app notification ───
-- The push notification is still sent by the existing send-invite-notification
-- edge function (unchanged). We only add the INSERT into notifications here.

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

    -- In-app notification
    SELECT title INTO v_event_title FROM events WHERE id = NEW.event_id;
    PERFORM public.insert_notification(
      NEW.user_id,
      'event_invite',
      'New event invitation',
      'You''ve been invited to "' || coalesce(v_event_title, 'an event') || '"',
      NEW.event_id::text
    );

    -- Push notification (existing edge function, unchanged)
    SELECT decrypted_secret INTO v_service_role_key
    FROM vault.decrypted_secrets
    WHERE name = 'service_role_key'
    LIMIT 1;

    IF v_service_role_key IS NOT NULL THEN
      PERFORM net.http_post(
        url     := 'https://qgeocaectbdfonrorwco.supabase.co'
                   || '/functions/v1/send-invite-notification',
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

-- ── 6. Update handle_waitlist_promotion to also write an in-app notification ──

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

    -- In-app notification
    SELECT e.title INTO v_event_title
    FROM event_sessions es
    JOIN events e ON e.id = es.event_id
    WHERE es.id = NEW.session_id;

    PERFORM public.insert_notification(
      NEW.user_id,
      'session_promoted',
      '🎉 You''re in!',
      'Your spot for "' || coalesce(v_event_title, 'the event') || '" is confirmed.',
      NEW.session_id::text
    );

    -- Push notification (existing edge function, unchanged)
    SELECT decrypted_secret INTO v_service_role_key
    FROM vault.decrypted_secrets
    WHERE name = 'service_role_key'
    LIMIT 1;

    IF v_service_role_key IS NOT NULL THEN
      PERFORM net.http_post(
        url     := 'https://qgeocaectbdfonrorwco.supabase.co'
                   || '/functions/v1/send-waitlist-promoted-notification',
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

-- ── 7. notify_invite_response: organizer notified when invite is accepted/declined ──

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

    -- Don't notify if organizer somehow accepted their own invite
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

    PERFORM public.insert_notification(
      v_organizer_id,
      v_notif_type,
      v_notif_title,
      'For "' || coalesce(v_event_title, 'your event') || '"',
      NEW.event_id::text
    );

    PERFORM public.call_push_edge_function(
      v_organizer_id,
      v_notif_type,
      v_notif_title,
      'For "' || coalesce(v_event_title, 'your event') || '"',
      jsonb_build_object('event_id', NEW.event_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_invite_response
  AFTER UPDATE ON public.event_guests
  FOR EACH ROW EXECUTE FUNCTION public.notify_invite_response();

-- ── 8. notify_member_kicked: user notified when removed by organizer ──────────

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

    PERFORM public.insert_notification(
      OLD.user_id,
      'event_kicked',
      'Removed from event',
      'You were removed from "' || coalesce(v_event_title, 'an event') || '"',
      OLD.event_id::text
    );

    PERFORM public.call_push_edge_function(
      OLD.user_id,
      'event_kicked',
      'Removed from event',
      'You were removed from "' || coalesce(v_event_title, 'an event') || '"',
      jsonb_build_object('event_id', OLD.event_id)
    );
  END IF;
  RETURN OLD;
END;
$$;

CREATE TRIGGER on_member_kicked
  AFTER DELETE ON public.event_guests
  FOR EACH ROW EXECUTE FUNCTION public.notify_member_kicked();

-- ── 9. notify_session_join_request: organizer notified of pending_review signup ──

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
    FROM event_sessions es
    JOIN events e ON e.id = es.event_id
    WHERE es.id = NEW.session_id;

    IF v_organizer_id IS NULL THEN RETURN NEW; END IF;

    v_requester_name := coalesce(NEW.display_name, 'Someone');

    PERFORM public.insert_notification(
      v_organizer_id,
      'session_join_request',
      'New join request',
      v_requester_name || ' wants to join "' || coalesce(v_event_title, 'your event')
        || '" – Session ' || coalesce(v_session_number::text, '?'),
      NEW.session_id::text,
      jsonb_build_object('event_id', v_event_id)
    );

    PERFORM public.call_push_edge_function(
      v_organizer_id,
      'session_join_request',
      'New join request',
      v_requester_name || ' wants to join "' || coalesce(v_event_title, 'your event')
        || '" – Session ' || coalesce(v_session_number::text, '?'),
      jsonb_build_object('session_id', NEW.session_id, 'event_id', v_event_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_session_join_request
  AFTER INSERT ON public.event_session_roster
  FOR EACH ROW EXECUTE FUNCTION public.notify_session_join_request();

-- ── 10. notify_session_decision: user notified of approval/rejection ──────────

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
    FROM event_sessions es
    JOIN events e ON e.id = es.event_id
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

    PERFORM public.insert_notification(
      NEW.user_id,
      v_notif_type,
      v_notif_title,
      v_notif_body,
      NEW.session_id::text,
      jsonb_build_object('event_id', v_event_id)
    );

    PERFORM public.call_push_edge_function(
      NEW.user_id,
      v_notif_type,
      v_notif_title,
      v_notif_body,
      jsonb_build_object('session_id', NEW.session_id, 'event_id', v_event_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_session_decision
  AFTER UPDATE ON public.event_session_roster
  FOR EACH ROW EXECUTE FUNCTION public.notify_session_decision();

-- ── 11. notify_session_demoted: user notified when moved from going → waitlisted ──

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
    FROM event_sessions es
    JOIN events e ON e.id = es.event_id
    WHERE es.id = NEW.session_id;

    PERFORM public.insert_notification(
      NEW.user_id,
      'session_demoted',
      'Moved to waitlist',
      'You''ve been moved to the waitlist for "' || coalesce(v_event_title, 'the event')
        || '" – Session ' || coalesce(v_session_number::text, '?'),
      NEW.session_id::text,
      jsonb_build_object('event_id', v_event_id)
    );

    PERFORM public.call_push_edge_function(
      NEW.user_id,
      'session_demoted',
      'Moved to waitlist',
      'You''ve been moved to the waitlist for "' || coalesce(v_event_title, 'the event')
        || '" – Session ' || coalesce(v_session_number::text, '?'),
      jsonb_build_object('session_id', NEW.session_id, 'event_id', v_event_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_session_demoted
  AFTER UPDATE ON public.event_session_roster
  FOR EACH ROW EXECUTE FUNCTION public.notify_session_demoted();

-- ── 12. notify_friend_request: user notified of incoming friend request ───────

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

    PERFORM public.insert_notification(
      NEW.addressee_id,
      'friend_request',
      'New friend request',
      coalesce(v_requester_name, 'Someone') || ' sent you a friend request',
      NEW.requester_id::text
    );

    PERFORM public.call_push_edge_function(
      NEW.addressee_id,
      'friend_request',
      'New friend request',
      coalesce(v_requester_name, 'Someone') || ' sent you a friend request',
      jsonb_build_object('requester_id', NEW.requester_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_friend_request
  AFTER INSERT ON public.friendships
  FOR EACH ROW EXECUTE FUNCTION public.notify_friend_request();

-- ── 13. notify_friend_accepted: requester notified when friend request accepted ──

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

    PERFORM public.insert_notification(
      NEW.requester_id,
      'friend_accepted',
      'Friend request accepted',
      coalesce(v_acceptor_name, 'Someone') || ' accepted your friend request',
      NEW.addressee_id::text
    );

    PERFORM public.call_push_edge_function(
      NEW.requester_id,
      'friend_accepted',
      'Friend request accepted',
      coalesce(v_acceptor_name, 'Someone') || ' accepted your friend request',
      jsonb_build_object('addressee_id', NEW.addressee_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_friend_accepted
  AFTER UPDATE ON public.friendships
  FOR EACH ROW EXECUTE FUNCTION public.notify_friend_accepted();
