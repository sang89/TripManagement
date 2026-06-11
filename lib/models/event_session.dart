class EventSession {
  final String id;
  final String eventId;
  final int sessionNumber;
  final DateTime startAt;
  final DateTime? endAt;
  final String inviteCode;
  final DateTime createdAt;
  // Denormalized by DB trigger — never requires a COUNT(*) on the roster.
  final int goingCount;
  final int waitlistCount;
  // Per-session signup settings (moved from events table).
  final int? capacity;
  final bool waitlistEnabled;
  final int? signupLockHours;

  const EventSession({
    required this.id,
    required this.eventId,
    required this.sessionNumber,
    required this.startAt,
    this.endAt,
    required this.inviteCode,
    required this.createdAt,
    this.goingCount = 0,
    this.waitlistCount = 0,
    this.capacity,
    this.waitlistEnabled = true,
    this.signupLockHours,
  });

  factory EventSession.fromJson(Map<String, dynamic> json) => EventSession(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        sessionNumber: json['session_number'] as int,
        startAt: DateTime.parse(json['start_at'] as String),
        endAt: json['end_at'] != null
            ? DateTime.parse(json['end_at'] as String)
            : null,
        inviteCode: json['invite_code'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        goingCount: json['going_count'] as int? ?? 0,
        waitlistCount: json['waitlist_count'] as int? ?? 0,
        capacity: json['capacity'] as int?,
        waitlistEnabled: (json['waitlist_enabled'] as bool?) ?? true,
        signupLockHours: json['signup_lock_hours'] as int?,
      );

  bool get isFull =>
      capacity != null && goingCount >= capacity!;

  bool get isLocked =>
      signupLockHours != null &&
      DateTime.now()
          .isAfter(startAt.subtract(Duration(hours: signupLockHours!)));

  bool get hasEnded =>
      endAt != null
          ? DateTime.now().isAfter(endAt!)
          : DateTime.now().isAfter(startAt);

  bool get isUpcoming => startAt.isAfter(DateTime.now());

  EventSession copyWithCounts({int? goingCount, int? waitlistCount}) =>
      EventSession(
        id: id,
        eventId: eventId,
        sessionNumber: sessionNumber,
        startAt: startAt,
        endAt: endAt,
        inviteCode: inviteCode,
        createdAt: createdAt,
        goingCount: goingCount ?? this.goingCount,
        waitlistCount: waitlistCount ?? this.waitlistCount,
        capacity: capacity,
        waitlistEnabled: waitlistEnabled,
        signupLockHours: signupLockHours,
      );
}

class EventSessionRosterEntry {
  final String id;
  final String sessionId;
  final String? userId;
  final String displayName;
  final String? email;
  final String? phone;
  final String status; // 'going' | 'waitlisted'
  final int? signupOrder;
  final bool? attended;
  final bool signupConfirmed;
  final DateTime signedUpAt;

  const EventSessionRosterEntry({
    required this.id,
    required this.sessionId,
    this.userId,
    required this.displayName,
    this.email,
    this.phone,
    required this.status,
    this.signupOrder,
    this.attended,
    this.signupConfirmed = false,
    required this.signedUpAt,
  });

  factory EventSessionRosterEntry.fromJson(Map<String, dynamic> json) =>
      EventSessionRosterEntry(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        userId: json['user_id'] as String?,
        displayName: json['display_name'] as String? ?? '',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        status: json['status'] as String? ?? 'going',
        signupOrder: json['signup_order'] as int?,
        attended: json['attended'] as bool?,
        signupConfirmed: json['signup_confirmed'] as bool? ?? false,
        signedUpAt: json['signed_up_at'] != null
            ? DateTime.parse(json['signed_up_at'] as String)
            : DateTime.now(),
      );

  bool get isGoing => status == 'going';
  bool get isWaitlisted => status == 'waitlisted';

  EventSessionRosterEntry copyWith({
    String? status,
    bool? attended,
    bool? signupConfirmed,
    int? signupOrder,
  }) =>
      EventSessionRosterEntry(
        id: id,
        sessionId: sessionId,
        userId: userId,
        displayName: displayName,
        email: email,
        phone: phone,
        status: status ?? this.status,
        signupOrder: signupOrder ?? this.signupOrder,
        attended: attended ?? this.attended,
        signupConfirmed: signupConfirmed ?? this.signupConfirmed,
        signedUpAt: signedUpAt,
      );
}
