-- Allow any event member (not just the organizer) to clear a queue row.
-- Also remove the auto-rotation to bottom — position management is now handled
-- explicitly via move_queue_to_position.
create or replace function public.clear_queue(
  p_activity_id uuid
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_event_id uuid;
begin
  select a.event_id
    into v_event_id
    from session_queue_activities a
   where a.id = p_activity_id;

  if not found then
    raise exception 'activity_not_found';
  end if;

  -- Any member of the event may evict a queue row.
  if not exists (
    select 1 from event_guests
     where event_id = v_event_id
       and user_id  = auth.uid()
       and status not in ('left', 'declined')
  ) and not exists (
    select 1 from events
     where id = v_event_id and created_by = auth.uid()
  ) then
    raise exception 'not_a_member';
  end if;

  delete from session_queue_entries where activity_id = p_activity_id;
end;
$$;

grant execute on function public.clear_queue(uuid) to authenticated;
