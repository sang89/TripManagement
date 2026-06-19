class EventPhoto {
  final String id;
  final String eventId;
  final String uploadedBy;
  final String storagePath;
  final String caption;
  final DateTime createdAt;

  // Resolved at load time from Supabase Storage public URL.
  final String? publicUrl;

  // 400 px-wide render URL for grid thumbnails — saves bandwidth vs full-res.
  // Null until withUrls() is called; falls back to publicUrl in the UI.
  final String? thumbnailUrl;

  const EventPhoto({
    required this.id,
    required this.eventId,
    required this.uploadedBy,
    required this.storagePath,
    required this.caption,
    required this.createdAt,
    this.publicUrl,
    this.thumbnailUrl,
  });

  factory EventPhoto.fromJson(Map<String, dynamic> json) => EventPhoto(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        uploadedBy: json['uploaded_by'] as String,
        storagePath: json['storage_path'] as String,
        caption: json['caption'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  EventPhoto withUrls({
    required String publicUrl,
    required String thumbnailUrl,
  }) =>
      EventPhoto(
        id: id,
        eventId: eventId,
        uploadedBy: uploadedBy,
        storagePath: storagePath,
        caption: caption,
        createdAt: createdAt,
        publicUrl: publicUrl,
        thumbnailUrl: thumbnailUrl,
      );

  EventPhoto copyWith({String? caption}) => EventPhoto(
        id: id,
        eventId: eventId,
        uploadedBy: uploadedBy,
        storagePath: storagePath,
        caption: caption ?? this.caption,
        createdAt: createdAt,
        publicUrl: publicUrl,
        thumbnailUrl: thumbnailUrl,
      );
}
