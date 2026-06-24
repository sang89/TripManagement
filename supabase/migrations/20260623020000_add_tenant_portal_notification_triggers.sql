-- Cross-user notifications for the tenant portal. These must be created
-- server-side (a tenant can't insert a notification for the landlord and vice
-- versa under the per-user RLS), so SECURITY DEFINER triggers do it.

-- Notify the landlord when a tenant files a request.
create or replace function notify_landlord_of_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_landlord uuid;
begin
  select user_id into v_landlord from properties where id = NEW.property_id;
  if v_landlord is not null then
    insert into notifications (user_id, app_id, type, title, body, reference_id)
    values (v_landlord, 'property_management', 'tenant_request',
            'New tenant request',
            coalesce(nullif(NEW.title, ''), 'A tenant submitted a request.'),
            NEW.id)
    on conflict do nothing;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_notify_landlord_of_request on tenant_requests;
create trigger trg_notify_landlord_of_request
  after insert on tenant_requests
  for each row execute function notify_landlord_of_request();

-- Notify on rent-payment two-step transitions: landlord on report, tenant on
-- confirmation.
create or replace function notify_payment_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_landlord uuid;
begin
  if NEW.status = 'tenant_reported'
     and NEW.status is distinct from OLD.status then
    select user_id into v_landlord from properties where id = NEW.property_id;
    if v_landlord is not null then
      insert into notifications (user_id, app_id, type, title, body, reference_id)
      values (v_landlord, 'property_management', 'payment_reported',
              'Payment reported',
              'A tenant reported a rent payment for confirmation.', NEW.id)
      on conflict do nothing;
    end if;
  elsif NEW.status = 'paid'
        and NEW.status is distinct from OLD.status then
    insert into notifications (user_id, app_id, type, title, body, reference_id)
    select tl.tenant_user_id, 'property_management', 'payment_confirmed',
           'Payment confirmed',
           'Your landlord confirmed your rent payment.', NEW.id
    from tenant_links tl
    where tl.tenant_id = NEW.tenant_id
      and tl.status = 'active'
      and tl.tenant_user_id is not null
    on conflict do nothing;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_notify_payment_status_change on rent_payments;
create trigger trg_notify_payment_status_change
  after update on rent_payments
  for each row execute function notify_payment_status_change();
