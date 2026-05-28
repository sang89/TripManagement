class TripMember {
  final String id;
  final String tripId;
  final String displayName;
  final String role;
  final String? userId;
  final String? email;
  final String? phone;
  final String status; // 'pending' | 'accepted' | 'declined' | 'left'
  final String? invitedBy; // userId of the person who sent the invite; null for the organizer's own row
  /// When true the user has opted out of future invitations to this specific trip.
  final bool blockReinvite;
  /// Profile picture URL — enriched in-memory from user_profiles; not stored
  /// directly in the trip_members table.
  final String? avatarUrl;
  final DateTime createdAt;

  const TripMember({
    required this.id,
    required this.tripId,
    required this.displayName,
    required this.role,
    this.userId,
    this.email,
    this.phone,
    this.status = 'accepted',
    this.invitedBy,
    this.blockReinvite = false,
    this.avatarUrl,
    required this.createdAt,
  });

  factory TripMember.fromJson(Map<String, dynamic> json) => TripMember(
        id: json['id'] as String,
        tripId: json['trip_id'] as String,
        displayName: json['display_name'] as String? ?? '',
        role: json['role'] as String? ?? 'member',
        userId: json['user_id'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        status: json['status'] as String? ?? 'accepted',
        invitedBy: json['invited_by'] as String?,
        blockReinvite: json['block_reinvite'] as bool? ?? false,
        avatarUrl: json['avatar_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'role': role,
        'user_id': ?userId,
        'email': ?email,
        'phone': ?phone,
        'invited_by': ?invitedBy,
      };

  TripMember copyWith({
    String? displayName,
    String? role,
    String? userId,
    String? email,
    String? phone,
    String? status,
    String? invitedBy,
    bool? blockReinvite,
    String? avatarUrl,
  }) =>
      TripMember(
        id: id,
        tripId: tripId,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        userId: userId ?? this.userId,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        status: status ?? this.status,
        invitedBy: invitedBy ?? this.invitedBy,
        blockReinvite: blockReinvite ?? this.blockReinvite,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        createdAt: createdAt,
      );
}
