alter table public.repairs add column if not exists receipt_url text not null default '';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'repair_receipts',
  'repair_receipts',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif', 'application/pdf']
)
on conflict (id) do nothing;

create policy "Repair receipts are publicly readable"
  on storage.objects for select
  using (bucket_id = 'repair_receipts');

create policy "Users can upload repair receipts"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'repair_receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can update their repair receipts"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'repair_receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete their repair receipts"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'repair_receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
