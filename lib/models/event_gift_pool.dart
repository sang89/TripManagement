class EventGiftPool {
  final String id;
  final String eventId;
  final String giftName;
  final double targetAmount;
  final String createdBy;
  final DateTime createdAt;
  final List<EventGiftPledge> pledges;

  const EventGiftPool({
    required this.id,
    required this.eventId,
    required this.giftName,
    required this.targetAmount,
    required this.createdBy,
    required this.createdAt,
    this.pledges = const [],
  });

  double get totalPledged =>
      pledges.fold(0, (sum, p) => sum + p.amount);

  factory EventGiftPool.fromJson(Map<String, dynamic> json) => EventGiftPool(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        giftName: json['gift_name'] as String,
        targetAmount: (json['target_amount'] as num).toDouble(),
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        pledges: (json['event_gift_pledges'] as List<dynamic>? ?? [])
            .map((p) => EventGiftPledge.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}

class EventGiftPledge {
  final String id;
  final String poolId;
  final String pledgedBy;
  final String pledgedByName;
  final double amount;
  final DateTime pledgedAt;

  const EventGiftPledge({
    required this.id,
    required this.poolId,
    required this.pledgedBy,
    required this.pledgedByName,
    required this.amount,
    required this.pledgedAt,
  });

  factory EventGiftPledge.fromJson(Map<String, dynamic> json) =>
      EventGiftPledge(
        id: json['id'] as String,
        poolId: json['pool_id'] as String,
        pledgedBy: json['pledged_by'] as String,
        pledgedByName: json['pledged_by_name'] as String,
        amount: (json['amount'] as num).toDouble(),
        pledgedAt: DateTime.parse(json['pledged_at'] as String),
      );
}
