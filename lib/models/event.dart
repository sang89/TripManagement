import 'event_guest.dart';

class Event {
  final String id;
  final String createdBy;
  final String title;
  final String description;
  final String location;
  final double? locationLat;
  final double? locationLng;
  final DateTime startAt;
  final DateTime? endAt;
  final int? capacity;
  final String inviteCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<EventGuest> guests;

  // Enriched in-memory.
  final String? organizerName;

  const Event({
    required this.id,
    required this.createdBy,
    required this.title,
    required this.description,
    required this.location,
    this.locationLat,
    this.locationLng,
    required this.startAt,
    this.endAt,
    this.capacity,
    required this.inviteCode,
    required this.createdAt,
    required this.updatedAt,
    required this.guests,
    this.organizerName,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        id: json['id'] as String,
        createdBy: json['created_by'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        location: json['location'] as String? ?? '',
        locationLat: (json['location_lat'] as num?)?.toDouble(),
        locationLng: (json['location_lng'] as num?)?.toDouble(),
        startAt: DateTime.parse(json['start_at'] as String),
        endAt: json['end_at'] != null
            ? DateTime.parse(json['end_at'] as String)
            : null,
        capacity: json['capacity'] as int?,
        inviteCode: json['invite_code'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        guests: (json['event_guests'] as List<dynamic>? ?? [])
            .map((g) => EventGuest.fromJson(g as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'location': location,
        if (locationLat != null) 'location_lat': locationLat,
        if (locationLng != null) 'location_lng': locationLng,
        'start_at': startAt.toUtc().toIso8601String(),
        if (endAt != null) 'end_at': endAt!.toUtc().toIso8601String(),
        if (capacity != null) 'capacity': capacity,
      };

  Event copyWith({
    String? title,
    String? description,
    String? location,
    double? locationLat,
    bool clearLocationLat = false,
    double? locationLng,
    bool clearLocationLng = false,
    DateTime? startAt,
    DateTime? endAt,
    bool clearEndAt = false,
    int? capacity,
    bool clearCapacity = false,
    List<EventGuest>? guests,
    String? organizerName,
  }) =>
      Event(
        id: id,
        createdBy: createdBy,
        title: title ?? this.title,
        description: description ?? this.description,
        location: location ?? this.location,
        locationLat: clearLocationLat ? null : (locationLat ?? this.locationLat),
        locationLng: clearLocationLng ? null : (locationLng ?? this.locationLng),
        startAt: startAt ?? this.startAt,
        endAt: clearEndAt ? null : (endAt ?? this.endAt),
        capacity: clearCapacity ? null : (capacity ?? this.capacity),
        inviteCode: inviteCode,
        createdAt: createdAt,
        updatedAt: updatedAt,
        guests: guests ?? this.guests,
        organizerName: organizerName ?? this.organizerName,
      );

  int get goingCount => guests.where((g) => g.rsvpStatus == 'going').length;
  int get maybeCount => guests.where((g) => g.rsvpStatus == 'maybe').length;
  int get declinedCount => guests.where((g) => g.rsvpStatus == 'declined').length;

  bool get isFull => capacity != null && goingCount >= capacity!;
}
