class UserProfile {
  final String id;
  final String userId;
  final String fullName;
  final String jobTitle;
  final String phone;
  /// Shared avatar URL (PropertyManagement). NOT displayed in TripManagement UI.
  final String avatarUrl;
  /// TripManagement-specific avatar URL. The only avatar shown in this app.
  final String? tripAvatarUrl;
  final bool mentionNotificationsEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.userId,
    this.fullName = '',
    this.jobTitle = '',
    this.phone = '',
    this.avatarUrl = '',
    this.tripAvatarUrl,
    this.mentionNotificationsEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// The avatar URL to display in this app: trip-specific avatar only.
  /// Returns null if no trip avatar has been set, so the UI shows initials.
  String? get displayAvatarUrl =>
      (tripAvatarUrl?.isNotEmpty == true) ? tripAvatarUrl : null;

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
        tripAvatarUrl: json['trip_avatar_url'] as String?,
        mentionNotificationsEnabled:
            json['mention_notifications_enabled'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  UserProfile copyWith({
    String? fullName,
    String? jobTitle,
    String? phone,
    bool? mentionNotificationsEnabled,
    String? tripAvatarUrl,
  }) =>
      UserProfile(
        id: id,
        userId: userId,
        fullName: fullName ?? this.fullName,
        jobTitle: jobTitle ?? this.jobTitle,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl,
        tripAvatarUrl: tripAvatarUrl ?? this.tripAvatarUrl,
        mentionNotificationsEnabled:
            mentionNotificationsEnabled ?? this.mentionNotificationsEnabled,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
