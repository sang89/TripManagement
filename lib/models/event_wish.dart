class EventWish {
  final String id;
  final String eventId;
  final String submittedBy;
  final String submittedByName;
  final String wishText;
  final DateTime createdAt;

  const EventWish({
    required this.id,
    required this.eventId,
    required this.submittedBy,
    required this.submittedByName,
    required this.wishText,
    required this.createdAt,
  });

  factory EventWish.fromJson(Map<String, dynamic> json) => EventWish(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        submittedBy: json['submitted_by'] as String,
        submittedByName: json['submitted_by_name'] as String,
        wishText: json['wish_text'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
