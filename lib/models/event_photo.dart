class EventPhoto {
  final String id;
  final String eventId;
  final String uploadedBy;
  final String storagePath;
  final String caption;
  final DateTime createdAt;

  // Resolved at load time from Supabase Storage public URL.
  final String? publicUrl;

  const EventPhoto({
    required this.id,
    required this.eventId,
    required this.uploadedBy,
    required this.storagePath,
    required this.caption,
    required this.createdAt,
    this.publicUrl,
  });

  factory EventPhoto.fromJson(Map<String, dynamic> json) => EventPhoto(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        uploadedBy: json['uploaded_by'] as String,
        storagePath: json['storage_path'] as String,
        caption: json['caption'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  EventPhoto withPublicUrl(String url) => EventPhoto(
        id: id,
        eventId: eventId,
        uploadedBy: uploadedBy,
        storagePath: storagePath,
        caption: caption,
        createdAt: createdAt,
        publicUrl: url,
      );
}
