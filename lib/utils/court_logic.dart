import '../models/tournament.dart';

// Pure court-scheduling helpers over a flat list of matches (across divisions).
// EventProvider delegates to these so the logic is unit-testable.

const _farOrder = 1 << 30;

/// Active (non-completed) matches assigned to [courtId], ordered by queue
/// position — the first element is "on court now".
List<TournamentMatch> courtQueue(List<TournamentMatch> all, String courtId) {
  return all
      .where((m) => m.courtId == courtId && !m.isCompleted)
      .toList()
    ..sort((a, b) => (a.scheduledOrder ?? _farOrder)
        .compareTo(b.scheduledOrder ?? _farOrder));
}

/// Entrant ids appearing in more than one active court-assigned match
/// (a player double-booked across courts).
Set<String> doubleBookedEntrants(List<TournamentMatch> all) {
  final counts = <String, int>{};
  for (final m in all) {
    if (m.courtId == null || m.isCompleted) continue;
    for (final id in [m.entrant1Id, m.entrant2Id].whereType<String>()) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  return counts.entries.where((e) => e.value > 1).map((e) => e.key).toSet();
}

/// Ready matches (both teams known, not a bye/completed) with no court yet.
List<TournamentMatch> unassignedReady(List<TournamentMatch> all) =>
    all.where((m) => m.courtId == null && m.isReady).toList();
