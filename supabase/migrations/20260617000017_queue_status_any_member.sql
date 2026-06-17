-- Allow any event member to set a queue row's status (waiting / active / ended).
-- Also reset status → 'waiting' when the queue is moved or cleared.

create or replace function public.set_queue_status(
  p_activity_id uuid,
  p_status       text   -- 'waiting' | 'active' | 'ended'
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_event_id uuid;
begin
  select event_id into v_event_id
  from session_queue_activities
  where id = p_activity_id;

  if not found then raise exception 'activity_not_found'; end if;

  if not exists (
    select 1 from event_guests
     where event_id = v_event_id and user_id = auth.uid()
       and status not in ('left', 'declined')
  ) and not exists (
    select 1 from events where id = v_event_id and created_by = auth.uid()
  ) then
    raise exception 'not_a_member';
  end if;

  update session_queue_activities
     set status = p_status
   where id = p_activity_id;
end;
$$;

grant execute on function public.set_queue_status(uuid, text) to authenticated;

-- Reset status → 'waiting' when a queue is moved to a new position.
create or replace function public.move_queue_to_position(
  p_activity_id uuid,
  p_session_id   uuid,
  p_new_position integer
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_current_pos integer;
begin
  select sort_order into v_current_pos
  from session_queue_activities
  where id = p_activity_id and session_id = p_session_id;

  if v_current_pos is null or v_current_pos = p_new_position then return; end if;

  if v_current_pos < p_new_position then
    update session_queue_activities
       set sort_order = sort_order - 1
     where session_id  = p_session_id
       and sort_order  > v_current_pos
       and sort_order <= p_new_position;
  else
    update session_queue_activities
       set sort_order = sort_order + 1
     where session_id  = p_session_id
       and sort_order >= p_new_position
       and sort_order  < v_current_pos;
  end if;

  update session_queue_activities
     set sort_order = p_new_position,
         status     = 'waiting'
   where id = p_activity_id;
end;
$$;

grant execute on function public.move_queue_to_position(uuid, uuid, integer) to authenticated;

-- Reset status → 'waiting' when a queue is evicted.
create or replace function public.clear_queue(p_activity_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_event_id uuid;
begin
  select a.event_id into v_event_id
  from session_queue_activities a
  where a.id = p_activity_id;

  if not found then raise exception 'activity_not_found'; end if;

  if not exists (
    select 1 from event_guests
     where event_id = v_event_id and user_id = auth.uid()
       and status not in ('left', 'declined')
  ) and not exists (
    select 1 from events where id = v_event_id and created_by = auth.uid()
  ) then
    raise exception 'not_a_member';
  end if;

  delete from session_queue_entries where activity_id = p_activity_id;

  update session_queue_activities
     set status = 'waiting'
   where id = p_activity_id;
end;
$$;

grant execute on function public.clear_queue(uuid) to authenticated;
