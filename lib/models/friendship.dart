class Friendship {
  final String id;
  final String requesterId;
  final String addresseeId;
  final String status; // 'pending' | 'accepted' | 'declined' | 'removed'
  final DateTime createdAt;

  // Enriched in-memory after fetch; not stored in the DB row.
  final String? otherDisplayName;
  final String? otherAvatarUrl;
  final String? otherEmail;
  final String? otherPhone;

  const Friendship({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.createdAt,
    this.otherDisplayName,
    this.otherAvatarUrl,
    this.otherEmail,
    this.otherPhone,
  });

  /// The ID of the other person, relative to [myUserId].
  String otherUserId(String myUserId) =>
      requesterId == myUserId ? addresseeId : requesterId;

  factory Friendship.fromJson(Map<String, dynamic> json) => Friendship(
        id: json['id'] as String,
        requesterId: json['requester_id'] as String,
        addresseeId: json['addressee_id'] as String,
        status: json['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'requester_id': requesterId,
        'addressee_id': addresseeId,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };

  Friendship copyWith({
    String? status,
    String? otherDisplayName,
    String? otherAvatarUrl,
    String? otherEmail,
    String? otherPhone,
  }) =>
      Friendship(
        id: id,
        requesterId: requesterId,
        addresseeId: addresseeId,
        status: status ?? this.status,
        createdAt: createdAt,
        otherDisplayName: otherDisplayName ?? this.otherDisplayName,
        otherAvatarUrl: otherAvatarUrl ?? this.otherAvatarUrl,
        otherEmail: otherEmail ?? this.otherEmail,
        otherPhone: otherPhone ?? this.otherPhone,
      );
}
