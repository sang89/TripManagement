class EventExpenseSplit {
  final String id;
  final String expenseId;
  final String guestId;
  final double amount;
  final bool settled;
  final DateTime? settledAt;

  // Enriched in-memory.
  final String? guestName;

  const EventExpenseSplit({
    required this.id,
    required this.expenseId,
    required this.guestId,
    required this.amount,
    required this.settled,
    this.settledAt,
    this.guestName,
  });

  factory EventExpenseSplit.fromJson(Map<String, dynamic> json) =>
      EventExpenseSplit(
        id: json['id'] as String,
        expenseId: json['expense_id'] as String,
        guestId: json['guest_id'] as String,
        amount: (json['amount'] as num).toDouble(),
        settled: json['settled'] as bool? ?? false,
        settledAt: json['settled_at'] != null
            ? DateTime.parse(json['settled_at'] as String)
            : null,
      );

  EventExpenseSplit copyWith({bool? settled, DateTime? settledAt, String? guestName}) =>
      EventExpenseSplit(
        id: id,
        expenseId: expenseId,
        guestId: guestId,
        amount: amount,
        settled: settled ?? this.settled,
        settledAt: settledAt ?? this.settledAt,
        guestName: guestName ?? this.guestName,
      );
}

class EventExpense {
  final String id;
  final String eventId;
  final String paidByUserId;
  final String paidByName;
  final double amount;
  final String description;
  final DateTime createdAt;
  final List<EventExpenseSplit> splits;

  const EventExpense({
    required this.id,
    required this.eventId,
    required this.paidByUserId,
    required this.paidByName,
    required this.amount,
    required this.description,
    required this.createdAt,
    required this.splits,
  });

  factory EventExpense.fromJson(Map<String, dynamic> json) => EventExpense(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        paidByUserId: json['paid_by_user_id'] as String,
        paidByName: json['paid_by_name'] as String? ?? '',
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
        splits: (json['event_expense_splits'] as List<dynamic>? ?? [])
            .map((s) => EventExpenseSplit.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  EventExpense copyWith({List<EventExpenseSplit>? splits}) => EventExpense(
        id: id,
        eventId: eventId,
        paidByUserId: paidByUserId,
        paidByName: paidByName,
        amount: amount,
        description: description,
        createdAt: createdAt,
        splits: splits ?? this.splits,
      );
}
