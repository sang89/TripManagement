-- Storage bucket for media (photos + videos) attached to tenant maintenance requests.
-- File size limit: 50 MB (videos can be large).
-- Public read so landlords can view photos their tenants uploaded.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'request_media',
  'request_media',
  true,
  52428800,
  array[
    'image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif',
    'video/mp4', 'video/quicktime', 'video/x-msvideo'
  ]
)
on conflict (id) do nothing;

create policy "Request media is publicly readable"
  on storage.objects for select
  using (bucket_id = 'request_media');

create policy "Users can upload request media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'request_media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete their request media"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'request_media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
