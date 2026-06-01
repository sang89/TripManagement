class ChatMessage {
  final String id;
  final String tripId;
  final String userId;
  final String content;
  final DateTime createdAt;

  // Enriched in-memory; not stored in the DB row.
  final String? senderName;
  final String? senderAvatarUrl;

  const ChatMessage({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.senderName,
    this.senderAvatarUrl,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        tripId: json['trip_id'] as String,
        userId: json['user_id'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'trip_id': tripId,
        'user_id': userId,
        'content': content,
      };

  ChatMessage copyWith({String? senderName, String? senderAvatarUrl}) =>
      ChatMessage(
        id: id,
        tripId: tripId,
        userId: userId,
        content: content,
        createdAt: createdAt,
        senderName: senderName ?? this.senderName,
        senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      );
}
