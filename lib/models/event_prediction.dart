class EventPrediction {
  final String id;
  final String eventId;
  final String submittedBy;
  final String submittedByName;
  final String predictionText;
  final DateTime createdAt;

  const EventPrediction({
    required this.id,
    required this.eventId,
    required this.submittedBy,
    required this.submittedByName,
    required this.predictionText,
    required this.createdAt,
  });

  factory EventPrediction.fromJson(Map<String, dynamic> json) =>
      EventPrediction(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        submittedBy: json['submitted_by'] as String,
        submittedByName: json['submitted_by_name'] as String,
        predictionText: json['prediction_text'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
