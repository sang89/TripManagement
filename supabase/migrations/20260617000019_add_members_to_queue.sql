-- Batch-adds multiple members to a queue in a single transaction.
-- Locks the queue activity row to prevent race conditions — concurrent callers
-- wait until this transaction commits before re-checking capacity.
-- Raises 'queue_full' if there are not enough empty spots for all members.
create or replace function public.add_members_to_queue(
  p_activity_id uuid,
  p_members      jsonb  -- [{user_id: uuid|null, display_name: text, avatar_url: text|null}]
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid       uuid    := auth.uid();
  v_event_id  uuid;
  v_spots     integer;
  v_claimed   bigint;
  v_pos       integer;
  v_member    jsonb;
  v_user_id   uuid;
begin
  -- Lock the activity row so concurrent batch-adds queue behind this one.
  select a.event_id, a.players_per_round
    into v_event_id, v_spots
    from session_queue_activities a
   where a.id = p_activity_id
     for update;

  if not found then raise exception 'activity_not_found'; end if;

  -- Caller must be an event member or organizer.
  if not exists (
    select 1 from event_guests
     where event_id = v_event_id and user_id = v_uid
       and status not in ('left', 'declined')
  ) and not exists (
    select 1 from events where id = v_event_id and created_by = v_uid
  ) then
    raise exception 'not_member';
  end if;

  -- Re-count occupancy inside the lock.
  select count(*) into v_claimed
    from session_queue_entries where activity_id = p_activity_id;

  if v_spots - v_claimed < jsonb_array_length(p_members) then
    raise exception 'queue_full';
  end if;

  v_pos := v_claimed::integer;
  for v_member in select * from jsonb_array_elements(p_members) loop
    v_user_id := case
      when v_member->>'user_id' is null or v_member->>'user_id' = 'null' then null
      else (v_member->>'user_id')::uuid
    end;

    -- Skip silently if this app user is already in the queue.
    if v_user_id is not null and exists (
      select 1 from session_queue_entries
       where activity_id = p_activity_id and user_id = v_user_id
    ) then
      continue;
    end if;

    v_pos := v_pos + 1;
    insert into session_queue_entries
      (activity_id, user_id, display_name, avatar_url, status, queue_position)
    values (
      p_activity_id,
      v_user_id,
      coalesce(nullif(trim(v_member->>'display_name'), ''), 'Guest'),
      nullif(v_member->>'avatar_url', 'null'),
      'playing',
      v_pos
    );
  end loop;
end;
$$;

grant execute on function public.add_members_to_queue(uuid, jsonb) to authenticated;
