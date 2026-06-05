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

  const EventPollOption({
    required this.id,
    required this.pollId,
    required this.text,
    this.sortOrder = 0,
  });

  factory EventPollOption.fromJson(Map<String, dynamic> json) =>
      EventPollOption(
        id: json['id'] as String,
        pollId: json['poll_id'] as String,
        text: json['text'] as String,
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}

class EventPoll {
  final String id;
  final String eventId;
  final String question;
  final String createdBy;
  final DateTime createdAt;
  final List<EventPollOption> options;
  final List<EventPollVote> votes;

  const EventPoll({
    required this.id,
    required this.eventId,
    required this.question,
    required this.createdBy,
    required this.createdAt,
    this.options = const [],
    this.votes = const [],
  });

  int get totalVotes => votes.length;

  int votesFor(String optionId) =>
      votes.where((v) => v.optionId == optionId).length;

  String? myVoteOptionId(String userId) =>
      votes.where((v) => v.userId == userId).firstOrNull?.optionId;

  String? myVoteId(String userId) =>
      votes.where((v) => v.userId == userId).firstOrNull?.id;

  EventPoll copyWithVotes(List<EventPollVote> newVotes) => EventPoll(
        id: id,
        eventId: eventId,
        question: question,
        createdBy: createdBy,
        createdAt: createdAt,
        options: options,
        votes: newVotes,
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
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      options: options,
      votes: votes,
    );
  }
}
