class UserProfile {
  final String id;
  final String userId;
  final String fullName;
  final String jobTitle;
  final String phone;
  final String avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.userId,
    this.fullName = '',
    this.jobTitle = '',
    this.phone = '',
    this.avatarUrl = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'job_title': jobTitle,
        'phone': phone,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        fullName: json['full_name'] as String? ?? '',
        jobTitle: json['job_title'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  UserProfile copyWith({
    String? fullName,
    String? jobTitle,
    String? phone,
  }) =>
      UserProfile(
        id: id,
        userId: userId,
        fullName: fullName ?? this.fullName,
        jobTitle: jobTitle ?? this.jobTitle,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
