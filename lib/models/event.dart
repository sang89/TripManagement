import 'event_guest.dart';
import 'event_stop.dart';

enum EventType {
  trip,
  birthday,
  wedding,
  social,
  quickBites;

  static EventType fromString(String? s) => switch (s) {
        'trip'        => EventType.trip,
        'birthday'    => EventType.birthday,
        'wedding'     => EventType.wedding,
        'quick_bites' => EventType.quickBites,
        _             => EventType.social,
      };

  String get dbValue => switch (this) {
        EventType.quickBites => 'quick_bites',
        _ => name,
      };
}

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
  final EventType eventType;

  // Trip-type fields (only populated when eventType == EventType.trip).
  final String? startLocation;
  final double? startLat;
  final double? startLng;

  // Quick Bites fields (only populated when eventType == EventType.quickBites).
  final double? budgetPerHead;
  final List<String> cuisineTags;
  final DateTime? rsvpDeadline;
  final String? vibe;

  final List<EventGuest> guests;
  final List<EventStop> stops;

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
    this.eventType = EventType.social,
    this.startLocation,
    this.startLat,
    this.startLng,
    this.budgetPerHead,
    this.cuisineTags = const [],
    this.rsvpDeadline,
    this.vibe,
    required this.guests,
    this.stops = const [],
    this.organizerName,
  });

  bool get isTrip => eventType == EventType.trip;
  bool get isQuickBites => eventType == EventType.quickBites;

  factory Event.fromJson(Map<String, dynamic> json) {
    final rawStops = (json['event_stops'] as List<dynamic>? ?? [])
        .map((s) => EventStop.fromJson(s as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Event(
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
      eventType: EventType.fromString(json['event_type'] as String?),
      startLocation: json['start_location'] as String?,
      startLat: (json['start_lat'] as num?)?.toDouble(),
      startLng: (json['start_lng'] as num?)?.toDouble(),
      budgetPerHead: (json['budget_per_head'] as num?)?.toDouble(),
      cuisineTags: (json['cuisine_tags'] as List<dynamic>? ?? [])
          .map((t) => t as String)
          .toList(),
      rsvpDeadline: json['rsvp_deadline'] != null
          ? DateTime.parse(json['rsvp_deadline'] as String)
          : null,
      vibe: json['vibe'] as String?,
      guests: (json['event_guests'] as List<dynamic>? ?? [])
          .map((g) => EventGuest.fromJson(g as Map<String, dynamic>))
          .toList(),
      stops: rawStops,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'location': location,
        if (locationLat != null) 'location_lat': locationLat,
        if (locationLng != null) 'location_lng': locationLng,
        'start_at': startAt.toUtc().toIso8601String(),
        if (endAt != null) 'end_at': endAt!.toUtc().toIso8601String(),
        if (capacity != null) 'capacity': capacity,
        'event_type': eventType.dbValue,
        if (startLocation != null) 'start_location': startLocation,
        if (startLat != null) 'start_lat': startLat,
        if (startLng != null) 'start_lng': startLng,
        if (budgetPerHead != null) 'budget_per_head': budgetPerHead,
        'cuisine_tags': cuisineTags,
        if (rsvpDeadline != null) 'rsvp_deadline': rsvpDeadline!.toUtc().toIso8601String(),
        if (vibe != null) 'vibe': vibe,
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
    EventType? eventType,
    String? startLocation,
    bool clearStartLocation = false,
    double? startLat,
    bool clearStartLat = false,
    double? startLng,
    bool clearStartLng = false,
    double? budgetPerHead,
    bool clearBudgetPerHead = false,
    List<String>? cuisineTags,
    DateTime? rsvpDeadline,
    bool clearRsvpDeadline = false,
    String? vibe,
    bool clearVibe = false,
    List<EventGuest>? guests,
    List<EventStop>? stops,
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
        eventType: eventType ?? this.eventType,
        startLocation: clearStartLocation ? null : (startLocation ?? this.startLocation),
        startLat: clearStartLat ? null : (startLat ?? this.startLat),
        startLng: clearStartLng ? null : (startLng ?? this.startLng),
        budgetPerHead: clearBudgetPerHead ? null : (budgetPerHead ?? this.budgetPerHead),
        cuisineTags: cuisineTags ?? this.cuisineTags,
        rsvpDeadline: clearRsvpDeadline ? null : (rsvpDeadline ?? this.rsvpDeadline),
        vibe: clearVibe ? null : (vibe ?? this.vibe),
        guests: guests ?? this.guests,
        stops: stops ?? this.stops,
        organizerName: organizerName ?? this.organizerName,
      );

  int get goingCount =>
      guests.where((g) => g.status == 'going' || g.status == 'accepted').length;
  int get maybeCount => guests.where((g) => g.status == 'maybe').length;
  int get declinedCount => guests.where((g) => g.status == 'declined').length;
  int get pendingCount => guests.where((g) => g.status == 'pending').length;

  bool get isFull => capacity != null && goingCount >= capacity!;
}
