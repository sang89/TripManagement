class BlockedUser {
  final String userId;
  final String fullName;
  final String avatarUrl;
  final DateTime blockedAt;

  const BlockedUser({
    required this.userId,
    required this.fullName,
    required this.avatarUrl,
    required this.blockedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
        userId: json['user_id'] as String,
        fullName: json['full_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String? ?? '',
        blockedAt: DateTime.parse(json['blocked_at'] as String),
      );
}
