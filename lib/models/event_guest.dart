class EventGuest {
  final String id;
  final String eventId;
  final String? userId;
  final String displayName;
  final String? email;
  final String? phone;
  final String rsvpStatus; // 'going' | 'maybe' | 'declined'
  final DateTime rsvpAt;
  final DateTime createdAt;

  // Enriched in-memory.
  final String? avatarUrl;

  const EventGuest({
    required this.id,
    required this.eventId,
    this.userId,
    required this.displayName,
    this.email,
    this.phone,
    required this.rsvpStatus,
    required this.rsvpAt,
    required this.createdAt,
    this.avatarUrl,
  });

  factory EventGuest.fromJson(Map<String, dynamic> json) => EventGuest(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        userId: json['user_id'] as String?,
        displayName: json['display_name'] as String? ?? '',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        rsvpStatus: json['rsvp_status'] as String? ?? 'going',
        rsvpAt: json['rsvp_at'] != null
            ? DateTime.parse(json['rsvp_at'] as String)
            : DateTime.now(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  EventGuest copyWith({String? rsvpStatus, String? displayName, String? avatarUrl}) =>
      EventGuest(
        id: id,
        eventId: eventId,
        userId: userId,
        displayName: displayName ?? this.displayName,
        email: email,
        phone: phone,
        rsvpStatus: rsvpStatus ?? this.rsvpStatus,
        rsvpAt: rsvpAt,
        createdAt: createdAt,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );
}
