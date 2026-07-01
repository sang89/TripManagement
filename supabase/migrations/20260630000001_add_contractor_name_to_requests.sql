alter table tenant_requests
  add column if not exists contractor_name text not null default '';
