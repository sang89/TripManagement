alter table repairs
  add column if not exists receipt_urls text[] not null default '{}';

-- Migrate any existing single receipt_url into the array.
update repairs
  set receipt_urls = array[receipt_url]
  where receipt_url is not null and receipt_url <> '';
