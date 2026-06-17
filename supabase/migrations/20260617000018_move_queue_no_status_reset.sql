-- Remove the automatic status reset from move_queue_to_position.
-- Dragging a queue to reorder it should preserve its playing/waiting status.
-- The "Just Played! Back in Line" flow resets status explicitly via set_queue_status.
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
     set sort_order = p_new_position
   where id = p_activity_id;
end;
$$;

grant execute on function public.move_queue_to_position(uuid, uuid, integer) to authenticated;
