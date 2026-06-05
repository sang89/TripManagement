class EventBringItem {
  final String id;
  final String eventId;
  final String label;
  final String? note;
  final String? assignedToName;
  final bool isDone;
  final String createdBy;
  final DateTime createdAt;

  const EventBringItem({
    required this.id,
    required this.eventId,
    required this.label,
    this.note,
    this.assignedToName,
    this.isDone = false,
    required this.createdBy,
    required this.createdAt,
  });

  bool get isAssigned => assignedToName != null && assignedToName!.isNotEmpty;

  List<String> get assignedToNames =>
      isAssigned ? assignedToName!.split(', ') : [];

  factory EventBringItem.fromJson(Map<String, dynamic> json) => EventBringItem(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        label: json['label'] as String,
        note: json['note'] as String?,
        assignedToName: json['assigned_to_name'] as String?,
        isDone: json['is_done'] as bool? ?? false,
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  EventBringItem copyWith({
    String? assignedToName,
    bool clearAssignedToName = false,
    bool? isDone,
  }) =>
      EventBringItem(
        id: id,
        eventId: eventId,
        label: label,
        note: note,
        assignedToName:
            clearAssignedToName ? null : (assignedToName ?? this.assignedToName),
        isDone: isDone ?? this.isDone,
        createdBy: createdBy,
        createdAt: createdAt,
      );
}
