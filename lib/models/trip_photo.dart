class TripPhoto {
  final String id;
  final String tripId;
  final String uploadedBy;
  final String storagePath;
  final String caption;
  final DateTime createdAt;

  final String? publicUrl;

  const TripPhoto({
    required this.id,
    required this.tripId,
    required this.uploadedBy,
    required this.storagePath,
    required this.caption,
    required this.createdAt,
    this.publicUrl,
  });

  factory TripPhoto.fromJson(Map<String, dynamic> json) => TripPhoto(
        id: json['id'] as String,
        tripId: json['trip_id'] as String,
        uploadedBy: json['uploaded_by'] as String,
        storagePath: json['storage_path'] as String,
        caption: json['caption'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  TripPhoto withPublicUrl(String url) => TripPhoto(
        id: id,
        tripId: tripId,
        uploadedBy: uploadedBy,
        storagePath: storagePath,
        caption: caption,
        createdAt: createdAt,
        publicUrl: url,
      );
}
