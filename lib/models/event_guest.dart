class EventGuest {
  final String id;
  final String eventId;
  final String? userId;
  final String displayName;
  final String? email;
  final String? phone;
  // Non-trip events: 'going' | 'maybe' | 'declined'
  // Trip-type events: 'pending' | 'accepted' | 'declined' | 'left'
  final String status;
  final DateTime rsvpAt;
  final DateTime createdAt;
  final String? invitedBy;
  final bool blockReinvite;
  final String role;

  // Enriched in-memory.
  final String? avatarUrl;

  const EventGuest({
    required this.id,
    required this.eventId,
    this.userId,
    required this.displayName,
    this.email,
    this.phone,
    required this.status,
    required this.rsvpAt,
    required this.createdAt,
    this.invitedBy,
    this.blockReinvite = false,
    this.role = 'member',
    this.avatarUrl,
  });

  factory EventGuest.fromJson(Map<String, dynamic> json) => EventGuest(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        userId: json['user_id'] as String?,
        displayName: json['display_name'] as String? ?? '',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        status: json['status'] as String? ?? 'going',
        rsvpAt: json['rsvp_at'] != null
            ? DateTime.parse(json['rsvp_at'] as String)
            : DateTime.now(),
        createdAt: DateTime.parse(json['created_at'] as String),
        invitedBy: json['invited_by'] as String?,
        blockReinvite: json['block_reinvite'] as bool? ?? false,
        role: json['role'] as String? ?? 'member',
        avatarUrl: json['avatar_url'] as String?,
      );

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted' || status == 'going';

  EventGuest copyWith({
    String? status,
    String? displayName,
    String? avatarUrl,
    bool? blockReinvite,
    String? invitedBy,
  }) =>
      EventGuest(
        id: id,
        eventId: eventId,
        userId: userId,
        displayName: displayName ?? this.displayName,
        email: email,
        phone: phone,
        status: status ?? this.status,
        rsvpAt: rsvpAt,
        createdAt: createdAt,
        invitedBy: invitedBy ?? this.invitedBy,
        blockReinvite: blockReinvite ?? this.blockReinvite,
        role: role,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );
}
