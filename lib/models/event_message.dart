class EventMessageReaction {
  final String id;
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  const EventMessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  factory EventMessageReaction.fromJson(Map<String, dynamic> json) =>
      EventMessageReaction(
        id: json['id'] as String,
        messageId: json['message_id'] as String,
        userId: json['user_id'] as String,
        emoji: json['emoji'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class EventMessage {
  final String id;
  final String eventId;
  final String userId;
  final String content;
  final DateTime createdAt;

  // Enriched in-memory.
  final String? senderName;
  final String? senderAvatarUrl;
  final List<EventMessageReaction> reactions;

  const EventMessage({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.senderName,
    this.senderAvatarUrl,
    this.reactions = const [],
  });

  // Aggregate counts: {'🔥': 2, '😂': 1}
  Map<String, int> get reactionCounts => reactions.fold(<String, int>{},
      (map, r) => map..[r.emoji] = (map[r.emoji] ?? 0) + 1);

  Set<String> myReactionEmojis(String userId) =>
      reactions.where((r) => r.userId == userId).map((r) => r.emoji).toSet();

  static List<EventMessageReaction> _parseReactions(dynamic raw) {
    if (raw == null || raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(EventMessageReaction.fromJson)
        .toList();
  }

  factory EventMessage.fromJson(Map<String, dynamic> json) => EventMessage(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        userId: json['user_id'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        reactions: _parseReactions(json['event_message_reactions']),
      );

  EventMessage copyWith({
    String? senderName,
    String? senderAvatarUrl,
    List<EventMessageReaction>? reactions,
  }) =>
      EventMessage(
        id: id,
        eventId: eventId,
        userId: userId,
        content: content,
        createdAt: createdAt,
        senderName: senderName ?? this.senderName,
        senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
        reactions: reactions ?? this.reactions,
      );
}
