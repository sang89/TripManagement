import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/tournament.dart';
import 'package:trip_management/utils/scoring_rules.dart';

void main() {
  final badminton = ScoringConfig.defaultFor('badminton'); // 21, by2, cap30, bo3
  final pickleball = ScoringConfig.defaultFor('pickleball'); // 11, by2, no cap, bo3

  group('gameWinner — badminton (21, win by 2, cap 30)', () {
    test('21-19 is a valid win for side 1', () {
      expect(ScoringRules.gameWinner(badminton, 21, 19), 1);
    });
    test('19-21 is a win for side 2', () {
      expect(ScoringRules.gameWinner(badminton, 19, 21), 2);
    });
    test('21-20 is incomplete (lead < 2, below cap)', () {
      expect(ScoringRules.gameWinner(badminton, 21, 20), 0);
    });
    test('22-20 is valid', () {
      expect(ScoringRules.gameWinner(badminton, 22, 20), 1);
    });
    test('cap: 30-29 wins despite 1-point lead', () {
      expect(ScoringRules.gameWinner(badminton, 30, 29), 1);
    });
    test('15-10 is incomplete (below points-to-win)', () {
      expect(ScoringRules.gameWinner(badminton, 15, 10), 0);
    });
    test('equal score is never a winner', () {
      expect(ScoringRules.gameWinner(badminton, 21, 21), 0);
    });
  });

  group('gameWinner — pickleball (11, win by 2, no cap)', () {
    test('11-9 valid', () {
      expect(ScoringRules.gameWinner(pickleball, 11, 9), 1);
    });
    test('11-10 incomplete (lead < 2)', () {
      expect(ScoringRules.gameWinner(pickleball, 11, 10), 0);
    });
    test('12-10 valid', () {
      expect(ScoringRules.gameWinner(pickleball, 12, 10), 1);
    });
    test('no cap: 15-13 valid (kept going past 11)', () {
      expect(ScoringRules.gameWinner(pickleball, 15, 13), 1);
    });
  });

  group('matchWinner — best of 3', () {
    test('2-0 sweep', () {
      expect(
          ScoringRules.matchWinner(badminton, [(21, 10), (21, 15)]), 1);
    });
    test('2-1 for side 1', () {
      expect(
          ScoringRules.matchWinner(
              badminton, [(21, 10), (15, 21), (21, 18)]),
          1);
    });
    test('2-1 for side 2', () {
      expect(
          ScoringRules.matchWinner(
              badminton, [(10, 21), (21, 15), (18, 21)]),
          2);
    });
    test('1-1 is undecided', () {
      expect(
          ScoringRules.matchWinner(badminton, [(21, 10), (15, 21)]), 0);
    });
    test('incomplete games are ignored in the tally', () {
      // second game 21-20 is invalid → only 1 decided game → undecided.
      expect(
          ScoringRules.matchWinner(badminton, [(21, 10), (21, 20)]), 0);
    });
  });

  group('tieWinner', () {
    test('side reaches threshold', () {
      expect(ScoringRules.tieWinner([1, 1], 2), 1);
      expect(ScoringRules.tieWinner([2, 1, 2], 2), 2);
    });
    test('undecided below threshold', () {
      expect(ScoringRules.tieWinner([1], 2), 0);
      expect(ScoringRules.tieWinner([1, 2], 2), 0);
    });
    test('tally counts each side', () {
      expect(ScoringRules.tieTally([1, 2, 1]), (2, 1));
    });
  });

  group('gameTally', () {
    test('counts only decided games', () {
      final t = ScoringRules.gameTally(
          badminton, [(21, 10), (15, 21), (21, 20)]);
      expect(t, (1, 1)); // third game incomplete
    });
  });
}
