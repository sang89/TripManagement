import '../models/tournament.dart';

/// Pure scoring logic for a [ScoringConfig]. Used by the score-entry UI for live
/// validation/preview. The record_match_score RPC is the source of truth for
/// persisted winners (it derives them from the submitted scores server-side).
class ScoringRules {
  /// Winner of a single game: 1 (entrant1), 2 (entrant2), or 0 (incomplete /
  /// invalid score for this config).
  static int gameWinner(ScoringConfig c, int s1, int s2) {
    if (s1 == s2) return 0;
    final hi = s1 > s2 ? s1 : s2;
    final lo = s1 > s2 ? s2 : s1;
    final lead = hi - lo;
    final atCap = c.cap != null && hi >= c.cap!;
    final reached = hi >= c.pointsToWin && (!c.winByTwo || lead >= 2);
    if (!(atCap || reached)) return 0;
    return s1 > s2 ? 1 : 2;
  }

  static bool isGameComplete(ScoringConfig c, int s1, int s2) =>
      gameWinner(c, s1, s2) != 0;

  /// Match winner from a list of (entrant1Score, entrant2Score) games:
  /// 1, 2, or 0 (not yet decided). A side wins after taking [gamesToWin] games.
  static int matchWinner(ScoringConfig c, List<(int, int)> games) {
    var w1 = 0, w2 = 0;
    for (final g in games) {
      final w = gameWinner(c, g.$1, g.$2);
      if (w == 1) {
        w1++;
      } else if (w == 2) {
        w2++;
      }
    }
    if (w1 >= c.gamesToWin) return 1;
    if (w2 >= c.gamesToWin) return 2;
    return 0;
  }

  /// Tie winner from completed sub-match results. [submatchWinners] is the list
  /// of decided sub-match winner sides (1 or 2). Returns 1, 2, or 0 (undecided)
  /// once a side reaches [winThreshold].
  static int tieWinner(List<int> submatchWinners, int winThreshold) {
    final side1 = submatchWinners.where((w) => w == 1).length;
    final side2 = submatchWinners.where((w) => w == 2).length;
    if (side1 >= winThreshold) return 1;
    if (side2 >= winThreshold) return 2;
    return 0;
  }

  /// Sub-match wins so far for each side: (side1, side2).
  static (int, int) tieTally(List<int> submatchWinners) => (
        submatchWinners.where((w) => w == 1).length,
        submatchWinners.where((w) => w == 2).length,
      );

  /// Game wins so far for each side: (entrant1 games, entrant2 games).
  static (int, int) gameTally(ScoringConfig c, List<(int, int)> games) {
    var w1 = 0, w2 = 0;
    for (final g in games) {
      final w = gameWinner(c, g.$1, g.$2);
      if (w == 1) {
        w1++;
      } else if (w == 2) {
        w2++;
      }
    }
    return (w1, w2);
  }
}
