class EventToast {
  final String id;
  final String eventId;
  final String submittedBy;
  final String submittedByName;
  final String toastText;
  final String toastType; // 'sweet' | 'funny' | 'poem'
  final int sortOrder;
  final DateTime createdAt;

  const EventToast({
    required this.id,
    required this.eventId,
    required this.submittedBy,
    required this.submittedByName,
    required this.toastText,
    required this.toastType,
    required this.sortOrder,
    required this.createdAt,
  });

  factory EventToast.fromJson(Map<String, dynamic> json) => EventToast(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        submittedBy: json['submitted_by'] as String,
        submittedByName: json['submitted_by_name'] as String,
        toastText: json['toast_text'] as String,
        toastType: json['toast_type'] as String? ?? 'sweet',
        sortOrder: json['sort_order'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
