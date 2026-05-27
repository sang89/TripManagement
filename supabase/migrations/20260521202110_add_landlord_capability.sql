-- tenants: tracks applicants, active tenants, and former tenants per property
create table tenants (
  id                    uuid primary key default gen_random_uuid(),
  property_id           uuid references properties(id) on delete cascade not null,
  name                  text not null default '',
  email                 text not null default '',
  phone                 text not null default '',
  status                text not null default 'applicant', -- applicant|active|former
  screening_status      text not null default 'pending',   -- pending|approved|denied
  monthly_rent          numeric not null default 0,
  security_deposit      numeric not null default 0,
  lease_start           date,
  lease_end             date,
  move_in_date          date,
  move_out_date         date,
  notes                 text not null default '',
  checkr_invitation_url text,      -- stub: Checkr screening invite URL
  stripe_customer_id    text,      -- stub: future Stripe customer ID
  created_at            timestamptz not null default now()
);

alter table tenants enable row level security;

create policy "Users can manage their own tenants"
  on tenants
  using (
    property_id in (
      select id from properties where user_id = auth.uid()
    )
  );

-- rent_payments: monthly rent ledger per tenant
create table rent_payments (
  id                       uuid primary key default gen_random_uuid(),
  tenant_id                uuid references tenants(id) on delete cascade not null,
  property_id              uuid references properties(id) on delete cascade not null,
  amount                   numeric not null default 0,
  due_date                 date not null,
  paid_date                date,
  status                   text not null default 'pending', -- pending|paid|overdue|waived
  notes                    text not null default '',
  payment_method           text,   -- stub: 'cash'|'check'|'stripe'
  stripe_payment_intent_id text,   -- stub: Stripe PaymentIntent ID
  created_at               timestamptz not null default now()
);

alter table rent_payments enable row level security;

create policy "Users can manage their own rent payments"
  on rent_payments
  using (
    property_id in (
      select id from properties where user_id = auth.uid()
    )
  );
