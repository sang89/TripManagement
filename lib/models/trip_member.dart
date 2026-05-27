class TripMember {
  final String id;
  final String tripId;
  final String displayName;
  final String role;
  final String? userId;
  final String? email;
  final String? phone;
  final String status; // 'pending' | 'accepted' | 'declined'
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
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'role': role,
        'user_id': ?userId,
        'email': ?email,
        'phone': ?phone,
      };

  TripMember copyWith({
    String? displayName,
    String? role,
    String? userId,
    String? email,
    String? phone,
    String? status,
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
        createdAt: createdAt,
      );
}
