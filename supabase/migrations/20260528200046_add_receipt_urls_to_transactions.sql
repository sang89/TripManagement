alter table financial_transactions
  add column if not exists receipt_urls text[] not null default '{}';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'transaction_receipts',
  'transaction_receipts',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif', 'application/pdf']
)
on conflict (id) do nothing;

create policy "Users can manage their own transaction receipts"
  on storage.objects
  for all
  using (
    bucket_id = 'transaction_receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
