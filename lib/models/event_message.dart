class EventMessage {
  final String id;
  final String eventId;
  final String userId;
  final String content;
  final DateTime createdAt;

  // Enriched in-memory.
  final String? senderName;
  final String? senderAvatarUrl;

  const EventMessage({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.senderName,
    this.senderAvatarUrl,
  });

  factory EventMessage.fromJson(Map<String, dynamic> json) => EventMessage(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        userId: json['user_id'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  EventMessage copyWith({String? senderName, String? senderAvatarUrl}) =>
      EventMessage(
        id: id,
        eventId: eventId,
        userId: userId,
        content: content,
        createdAt: createdAt,
        senderName: senderName ?? this.senderName,
        senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      );
}
