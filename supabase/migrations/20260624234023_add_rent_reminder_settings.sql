-- Landlord-configurable rent reminder settings, one row per property.
create table rent_reminder_settings (
  id          uuid primary key default gen_random_uuid(),
  property_id uuid not null references properties(id) on delete cascade,
  enabled     boolean not null default true,
  days_before integer[] not null default '{3,1}',
  message     text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique(property_id)
);

-- Landlord can manage their own property's reminder settings.
alter table rent_reminder_settings enable row level security;

create policy "landlord_manage_reminder_settings"
  on rent_reminder_settings
  for all
  using (
    exists (
      select 1 from properties
      where properties.id = rent_reminder_settings.property_id
        and properties.user_id = auth.uid()
    )
  );

-- Add rent_reminder to the notifications type constraint.
alter table notifications
  drop constraint if exists notifications_type_check;

alter table notifications
  add constraint notifications_type_check
  check (type in (
    'lease_expiry', 'system', 'monthly_summary', 'rent_overdue',
    'rent_reminder', 'tenant_invite', 'tenant_request',
    'payment_reported', 'payment_confirmed', 'request_update'
  ));
