-- Moves a single queue row to a new sort_order position, shifting the rows in
-- between by ±1. Only the affected range is touched — O(range) instead of O(N),
-- and fires Realtime events only for rows that actually changed.
create or replace function public.move_queue_to_position(
  p_activity_id uuid,
  p_session_id   uuid,
  p_new_position integer   -- the sort_order value to move the row to
)
returns void
language plpgsql
security definer
as $$
declare
  v_current_pos integer;
begin
  select sort_order into v_current_pos
  from session_queue_activities
  where id = p_activity_id and session_id = p_session_id;

  if v_current_pos is null or v_current_pos = p_new_position then
    return;
  end if;

  if v_current_pos < p_new_position then
    -- Moving later: shift earlier every row in the affected range
    update session_queue_activities
       set sort_order = sort_order - 1
     where session_id    = p_session_id
       and sort_order    > v_current_pos
       and sort_order   <= p_new_position;
  else
    -- Moving earlier: shift later every row in the affected range
    update session_queue_activities
       set sort_order = sort_order + 1
     where session_id    = p_session_id
       and sort_order   >= p_new_position
       and sort_order    < v_current_pos;
  end if;

  update session_queue_activities
     set sort_order = p_new_position
   where id = p_activity_id;
end;
$$;

grant execute on function public.move_queue_to_position(uuid, uuid, integer) to authenticated;
