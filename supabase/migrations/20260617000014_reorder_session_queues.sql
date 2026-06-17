-- Atomically reorders session_queue_activities by updating sort_order for each
-- ID in the supplied array. One transaction, one network round-trip.
create or replace function public.reorder_session_queues(
  p_session_id uuid,
  p_ordered_ids uuid[]
)
returns void
language plpgsql
security definer
as $$
declare
  v_id  uuid;
  v_pos int := 0;
begin
  foreach v_id in array p_ordered_ids loop
    update public.session_queue_activities
       set sort_order = v_pos
     where id = v_id
       and session_id = p_session_id;
    v_pos := v_pos + 1;
  end loop;
end;
$$;

grant execute on function public.reorder_session_queues(uuid, uuid[]) to authenticated;
