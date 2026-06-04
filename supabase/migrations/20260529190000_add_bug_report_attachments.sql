alter table bug_reports
  add column if not exists attachment_urls text[] not null default '{}'::text[];

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'bug_report_attachments',
  'bug_report_attachments',
  false,
  52428800, -- 50 MB per file
  array[
    'image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif',
    'video/mp4', 'video/quicktime', 'video/x-msvideo', 'video/x-matroska'
  ]
)
on conflict (id) do nothing;

create policy "Users can upload their own bug report attachments"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'bug_report_attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
