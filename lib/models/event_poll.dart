class EventPollReaction {
  final String id;
  final String optionId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  const EventPollReaction({
    required this.id,
    required this.optionId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  factory EventPollReaction.fromJson(Map<String, dynamic> json) =>
      EventPollReaction(
        id: json['id'] as String,
        optionId: json['option_id'] as String,
        userId: json['user_id'] as String,
        emoji: json['emoji'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class EventPollVote {
  final String id;
  final String pollId;
  final String optionId;
  final String userId;
  final DateTime createdAt;

  const EventPollVote({
    required this.id,
    required this.pollId,
    required this.optionId,
    required this.userId,
    required this.createdAt,
  });

  factory EventPollVote.fromJson(Map<String, dynamic> json) => EventPollVote(
        id: json['id'] as String,
        pollId: json['poll_id'] as String,
        optionId: json['option_id'] as String,
        userId: json['user_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class EventPollOption {
  final String id;
  final String pollId;
  final String text;
  final int sortOrder;
  // Non-null for restaurant-vote options — stores Places API metadata.
  final Map<String, dynamic>? placeMetadata;
  final List<EventPollReaction> reactions;

  const EventPollOption({
    required this.id,
    required this.pollId,
    required this.text,
    this.sortOrder = 0,
    this.placeMetadata,
    this.reactions = const [],
  });

  EventPollOption copyWithReactions(List<EventPollReaction> r) =>
      EventPollOption(
        id: id,
        pollId: pollId,
        text: text,
        sortOrder: sortOrder,
        placeMetadata: placeMetadata,
        reactions: r,
      );

  static List<EventPollReaction> _parseReactions(dynamic raw) {
    if (raw == null || raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(EventPollReaction.fromJson)
        .toList();
  }

  factory EventPollOption.fromJson(Map<String, dynamic> json) =>
      EventPollOption(
        id: json['id'] as String,
        pollId: json['poll_id'] as String,
        text: json['text'] as String,
        sortOrder: json['sort_order'] as int? ?? 0,
        placeMetadata: json['place_metadata'] != null
            ? Map<String, dynamic>.from(json['place_metadata'] as Map)
            : null,
        reactions: _parseReactions(json['event_poll_reactions']),
      );
}

class EventPoll {
  final String id;
  final String eventId;
  final String question;
  final String pollType;
  final String createdBy;
  final DateTime createdAt;
  final List<EventPollOption> options;
  final List<EventPollVote> votes;

  const EventPoll({
    required this.id,
    required this.eventId,
    required this.question,
    this.pollType = 'general',
    required this.createdBy,
    required this.createdAt,
    this.options = const [],
    this.votes = const [],
  });

  bool get isRestaurantPoll => pollType == 'restaurant';

  int get totalVotes => votes.length;

  int votesFor(String optionId) =>
      votes.where((v) => v.optionId == optionId).length;

  String? myVoteOptionId(String userId) =>
      votes.where((v) => v.userId == userId).firstOrNull?.optionId;

  Set<String> myVotedOptionIds(String userId) =>
      votes.where((v) => v.userId == userId).map((v) => v.optionId).toSet();

  String? myVoteId(String userId) =>
      votes.where((v) => v.userId == userId).firstOrNull?.id;

  Map<String, int> reactionsFor(String optionId) {
    final rs = options.firstWhere((o) => o.id == optionId,
        orElse: () => EventPollOption(id: '', pollId: '', text: '')).reactions;
    return rs.fold(<String, int>{},
        (map, r) => map..[r.emoji] = (map[r.emoji] ?? 0) + 1);
  }

  Set<String> myReactionEmojis(String optionId, String userId) {
    final rs = options.firstWhere((o) => o.id == optionId,
        orElse: () => EventPollOption(id: '', pollId: '', text: '')).reactions;
    return rs.where((r) => r.userId == userId).map((r) => r.emoji).toSet();
  }

  EventPoll copyWithVotes(List<EventPollVote> newVotes) => EventPoll(
        id: id,
        eventId: eventId,
        question: question,
        pollType: pollType,
        createdBy: createdBy,
        createdAt: createdAt,
        options: options,
        votes: newVotes,
      );

  EventPoll copyWithOptionReactions(
      String optionId, List<EventPollReaction> reactions) =>
      EventPoll(
        id: id,
        eventId: eventId,
        question: question,
        pollType: pollType,
        createdBy: createdBy,
        createdAt: createdAt,
        options: options
            .map((o) => o.id == optionId ? o.copyWithReactions(reactions) : o)
            .toList(),
        votes: votes,
      );

  factory EventPoll.fromJson(Map<String, dynamic> json) {
    final options = (json['event_poll_options'] as List<dynamic>? ?? [])
        .map((o) => EventPollOption.fromJson(o as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final votes = (json['event_poll_votes'] as List<dynamic>? ?? [])
        .map((v) => EventPollVote.fromJson(v as Map<String, dynamic>))
        .toList();

    return EventPoll(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      question: json['question'] as String,
      pollType: json['poll_type'] as String? ?? 'general',
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      options: options,
      votes: votes,
    );
  }
}
