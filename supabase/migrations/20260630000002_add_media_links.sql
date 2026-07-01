create table if not exists media_links (
  code        text primary key,
  url         text not null,
  created_at  timestamptz not null default now()
);

-- Auto-delete links older than 30 days (optional hygiene — not enforced here,
-- but leaving a comment so a cron job can target this table later).
