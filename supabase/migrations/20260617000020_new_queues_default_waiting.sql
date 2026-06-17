-- Fix: newly created queues should default to 'waiting', not 'active'.
create or replace function public.setup_session_queues(
  p_session_id       uuid,
  p_count            integer,
  p_spots            integer,
  p_allow_duplicates boolean default false
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_event_id      uuid;
  v_existing_cnt  integer;
  v_max_order     integer;
  i               integer;
begin
  select es.event_id into v_event_id
  from event_sessions es where es.id = p_session_id;
  if not found then raise exception 'session_not_found'; end if;

  if not exists (select 1 from events where id = v_event_id and created_by = auth.uid()) then
    raise exception 'not_organizer';
  end if;

  if p_count < 1 or p_count > 50 then raise exception 'invalid_count'; end if;
  if p_spots < 1 or p_spots > 20 then raise exception 'invalid_spots'; end if;

  select count(*) into v_existing_cnt
  from session_queue_activities where session_id = p_session_id;

  -- Decreasing queue count: remove excess from the bottom.
  if p_count < v_existing_cnt then
    with ranked as (
      select id, row_number() over (order by sort_order desc) as rn
      from session_queue_activities where session_id = p_session_id
    )
    delete from session_queue_activities
    where id in (select id from ranked where rn <= v_existing_cnt - p_count);
  end if;

  -- Decreasing spots: kick entries beyond the new limit.
  if p_spots < (select coalesce(max(players_per_round), 0)
                from session_queue_activities where session_id = p_session_id) then
    delete from session_queue_entries sqe
    using session_queue_activities sqa
    where sqe.activity_id = sqa.id
      and sqa.session_id  = p_session_id
      and sqe.queue_position > p_spots;
  end if;

  -- Update all remaining activities (spots + flag).
  update session_queue_activities
     set players_per_round = p_spots,
         allow_duplicates  = p_allow_duplicates
   where session_id = p_session_id;

  -- Increasing queue count: append new activities with status = 'waiting'.
  if p_count > v_existing_cnt then
    select coalesce(max(sort_order), 0) into v_max_order
    from session_queue_activities where session_id = p_session_id;

    for i in (v_existing_cnt + 1)..p_count loop
      v_max_order := v_max_order + 1;
      insert into session_queue_activities
        (event_id, session_id, name, players_per_round, allow_duplicates,
         status, sort_order, created_by)
      values
        (v_event_id, p_session_id, 'Queue ' || i, p_spots, p_allow_duplicates,
         'waiting', v_max_order, auth.uid());
    end loop;
  end if;
end;
$$;

grant execute on function public.setup_session_queues(uuid, integer, integer, boolean) to authenticated;
