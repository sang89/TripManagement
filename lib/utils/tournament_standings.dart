import '../models/tournament.dart';

/// A computed standings row for one entrant in a round-robin (or pool).
class StandingRow {
  final String entrantId;
  final int played;
  final int won;
  final int lost;
  final int gamesWon;
  final int gamesLost;
  final int pointsFor;
  final int pointsAgainst;
  int rank;

  StandingRow({
    required this.entrantId,
    this.played = 0,
    this.won = 0,
    this.lost = 0,
    this.gamesWon = 0,
    this.gamesLost = 0,
    this.pointsFor = 0,
    this.pointsAgainst = 0,
    this.rank = 0,
  });

  int get gameDiff => gamesWon - gamesLost;
  int get pointDiff => pointsFor - pointsAgainst;
}

/// Computes standings from completed matches for the given entrants. Optionally
/// restrict to a single [poolId]. Tiebreakers, in order: wins → head-to-head →
/// game differential → point differential.
List<StandingRow> computeStandings(
  List<TournamentEntrant> entrants,
  List<TournamentMatch> matches, {
  String? poolId,
}) {
  final relevant = matches
      .where((m) =>
          m.status == MatchStatus.completed &&
          m.winnerEntrantId != null &&
          (poolId == null || m.poolId == poolId))
      .toList();

  final stats = <String, _MutableStat>{
    for (final e in entrants.where((e) => !e.isWithdrawn))
      e.id: _MutableStat(e.id),
  };

  for (final m in relevant) {
    final a = m.entrant1Id, b = m.entrant2Id;
    if (a == null || b == null) continue;
    final sa = stats[a], sb = stats[b];
    if (sa == null || sb == null) continue;

    sa.played++;
    sb.played++;
    if (m.winnerEntrantId == a) {
      sa.won++;
      sb.lost++;
    } else {
      sb.won++;
      sa.lost++;
    }

    for (final g in m.games) {
      sa.pointsFor += g.entrant1Score;
      sa.pointsAgainst += g.entrant2Score;
      sb.pointsFor += g.entrant2Score;
      sb.pointsAgainst += g.entrant1Score;
      if (g.entrant1Score > g.entrant2Score) {
        sa.gamesWon++;
        sb.gamesLost++;
      } else if (g.entrant2Score > g.entrant1Score) {
        sb.gamesWon++;
        sa.gamesLost++;
      }
    }
  }

  // Precompute head-to-head wins once (O(matches)) so the sort comparator is
  // O(1) per comparison instead of re-scanning every match — otherwise the sort
  // is O(n²·matches), catastrophic for large round-robins.
  final h2hWins = <String, Map<String, int>>{}; // winner → {loser → wins}
  for (final m in relevant) {
    final w = m.winnerEntrantId;
    final a = m.entrant1Id, b = m.entrant2Id;
    if (w == null || a == null || b == null) continue;
    final loser = w == a ? b : a;
    (h2hWins[w] ??= {})[loser] = ((h2hWins[w] ??= {})[loser] ?? 0) + 1;
  }
  // +1 if x beat y overall, -1 if y beat x, 0 otherwise.
  int headToHead(String x, String y) {
    final xw = h2hWins[x]?[y] ?? 0;
    final yw = h2hWins[y]?[x] ?? 0;
    return xw == yw ? 0 : (xw > yw ? 1 : -1);
  }

  final rows = stats.values
      .map((s) => StandingRow(
            entrantId: s.entrantId,
            played: s.played,
            won: s.won,
            lost: s.lost,
            gamesWon: s.gamesWon,
            gamesLost: s.gamesLost,
            pointsFor: s.pointsFor,
            pointsAgainst: s.pointsAgainst,
          ))
      .toList();

  rows.sort((a, b) {
    if (a.won != b.won) return b.won.compareTo(a.won);
    final h = headToHead(a.entrantId, b.entrantId);
    if (h != 0) return -h; // a beat b → a ranks higher
    if (a.gameDiff != b.gameDiff) return b.gameDiff.compareTo(a.gameDiff);
    if (a.pointDiff != b.pointDiff) return b.pointDiff.compareTo(a.pointDiff);
    return 0;
  });

  for (var i = 0; i < rows.length; i++) {
    rows[i].rank = i + 1;
  }
  return rows;
}

class _MutableStat {
  final String entrantId;
  int played = 0;
  int won = 0;
  int lost = 0;
  int gamesWon = 0;
  int gamesLost = 0;
  int pointsFor = 0;
  int pointsAgainst = 0;
  _MutableStat(this.entrantId);
}
