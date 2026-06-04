class TripExpenseSplit {
  final String id;
  final String expenseId;
  final String memberId; // trip_members.id
  final double amount;
  final bool settled;
  final DateTime? settledAt;

  const TripExpenseSplit({
    required this.id,
    required this.expenseId,
    required this.memberId,
    required this.amount,
    required this.settled,
    this.settledAt,
  });

  factory TripExpenseSplit.fromJson(Map<String, dynamic> json) =>
      TripExpenseSplit(
        id: json['id'] as String,
        expenseId: json['expense_id'] as String,
        memberId: json['member_id'] as String,
        amount: (json['amount'] as num).toDouble(),
        settled: json['settled'] as bool? ?? false,
        settledAt: json['settled_at'] != null
            ? DateTime.parse(json['settled_at'] as String)
            : null,
      );

  TripExpenseSplit copyWith({bool? settled, DateTime? settledAt}) =>
      TripExpenseSplit(
        id: id,
        expenseId: expenseId,
        memberId: memberId,
        amount: amount,
        settled: settled ?? this.settled,
        settledAt: settledAt ?? this.settledAt,
      );
}

class TripExpense {
  final String id;
  final String tripId;
  final String paidByUserId;
  final String paidByName;
  final double amount;
  final String description;
  final DateTime createdAt;
  final List<TripExpenseSplit> splits;

  const TripExpense({
    required this.id,
    required this.tripId,
    required this.paidByUserId,
    required this.paidByName,
    required this.amount,
    required this.description,
    required this.createdAt,
    required this.splits,
  });

  factory TripExpense.fromJson(Map<String, dynamic> json) => TripExpense(
        id: json['id'] as String,
        tripId: json['trip_id'] as String,
        paidByUserId: json['paid_by_user_id'] as String,
        paidByName: json['paid_by_name'] as String? ?? '',
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
        splits: (json['trip_expense_splits'] as List<dynamic>? ?? [])
            .map((s) => TripExpenseSplit.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  TripExpense copyWith({List<TripExpenseSplit>? splits}) => TripExpense(
        id: id,
        tripId: tripId,
        paidByUserId: paidByUserId,
        paidByName: paidByName,
        amount: amount,
        description: description,
        createdAt: createdAt,
        splits: splits ?? this.splits,
      );
}
