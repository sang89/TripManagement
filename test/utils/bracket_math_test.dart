import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/tournament.dart';
import 'package:trip_management/utils/bracket_math.dart';

void main() {
  group('nextPowerOfTwo', () {
    test('rounds up to power of two, min 2', () {
      expect(nextPowerOfTwo(1), 2);
      expect(nextPowerOfTwo(2), 2);
      expect(nextPowerOfTwo(3), 4);
      expect(nextPowerOfTwo(5), 8);
      expect(nextPowerOfTwo(8), 8);
      expect(nextPowerOfTwo(9), 16);
      expect(nextPowerOfTwo(16), 16);
      expect(nextPowerOfTwo(17), 32);
    });
  });

  group('bracketCenterSlots (tree layout)', () {
    test('first round is evenly spaced at half-slot offsets', () {
      expect(bracketCenterSlots(0, 0), 0.5);
      expect(bracketCenterSlots(0, 1), 1.5);
      expect(bracketCenterSlots(0, 3), 3.5);
    });

    test('each later match is centred between its two feeders', () {
      // round r+1 match i sits at the midpoint of round r matches 2i and 2i+1.
      for (var r = 0; r < 5; r++) {
        for (var i = 0; i < 4; i++) {
          final mid =
              (bracketCenterSlots(r, 2 * i) + bracketCenterSlots(r, 2 * i + 1)) /
                  2;
          expect(bracketCenterSlots(r + 1, i), mid,
              reason: 'round ${r + 1} match $i not centred');
        }
      }
    });

    test('the single final is centred on the whole bracket height', () {
      // 8-team bracket: 4 first-round slots → final centre at slot 2.0.
      expect(bracketCenterSlots(2, 0), 2.0);
    });
  });

  group('seedOrder', () {
    test('size 2 and 4', () {
      expect(seedOrder(2), [1, 2]);
      expect(seedOrder(4), [1, 4, 2, 3]);
    });

    test('size 8: all seeds present, pairings sum to size+1', () {
      final o = seedOrder(8);
      expect(o.length, 8);
      expect(o.toSet(), {1, 2, 3, 4, 5, 6, 7, 8});
      for (var m = 0; m < 4; m++) {
        expect(o[2 * m] + o[2 * m + 1], 9);
      }
    });

    test('seed 1 and seed 2 are in opposite halves (any size)', () {
      for (final size in [4, 8, 16, 32]) {
        final o = seedOrder(size);
        final s1 = o.indexOf(1);
        final s2 = o.indexOf(2);
        expect(s1 < size ~/ 2, isTrue, reason: 'seed1 in first half for $size');
        expect(s2 >= size ~/ 2, isTrue,
            reason: 'seed2 in second half for $size');
      }
    });
  });

  List<String> ids(int n) => List.generate(n, (i) => 'e${i + 1}');

  group('buildSingleElimination', () {
    test('throws for < 2 entrants', () {
      expect(() => buildSingleElimination(ids(1)), throwsArgumentError);
    });

    test('n=2: single final, no byes, no next match', () {
      final plan = buildSingleElimination(ids(2));
      expect(plan.matches.length, 1);
      final m = plan.matches.single;
      expect(m.status, MatchStatus.scheduled);
      expect(m.entrant1Id, 'e1');
      expect(m.entrant2Id, 'e2');
      expect(m.nextMatchIdx, isNull);
      expect(plan.seeds, {'e1': 1, 'e2': 2});
    });

    test('n=4: 3 matches, round 1 wired into the final, no byes', () {
      final plan = buildSingleElimination(ids(4));
      expect(plan.matches.length, 3);
      final r1 = plan.matches.where((m) => m.roundNumber == 1).toList();
      final r2 = plan.matches.where((m) => m.roundNumber == 2).toList();
      expect(r1.length, 2);
      expect(r2.length, 1);
      expect(r1.every((m) => m.status == MatchStatus.scheduled), isTrue);
      // Both round-1 matches feed the final.
      expect(r1.every((m) => m.nextMatchIdx == r2.single.idx), isTrue);
      expect({r1[0].nextMatchSlot, r1[1].nextMatchSlot}, {1, 2});
      // Every entrant appears exactly once in round 1.
      final inR1 = <String>{};
      for (final m in r1) {
        inR1.addAll([m.entrant1Id, m.entrant2Id].whereType<String>());
      }
      expect(inR1, {'e1', 'e2', 'e3', 'e4'});
    });

    test('n=3: 1 bye for the top seed, pre-advanced into the final', () {
      final plan = buildSingleElimination(ids(3));
      expect(plan.matches.length, 3); // size 4 → 3 matches
      final byes = plan.matches.where((m) => m.status == MatchStatus.bye).toList();
      expect(byes.length, 1);
      expect(byes.single.winnerEntrantId, 'e1'); // top seed gets the bye
      // Final has e1 pre-advanced into one slot, the other slot still TBD.
      final finalMatch =
          plan.matches.firstWhere((m) => m.roundNumber == 2);
      final slots = [finalMatch.entrant1Id, finalMatch.entrant2Id];
      expect(slots.contains('e1'), isTrue);
      expect(slots.contains(null), isTrue);
      expect(finalMatch.status, MatchStatus.pending);
      // The real round-1 match is e2 vs e3.
      final realR1 = plan.matches.firstWhere(
          (m) => m.roundNumber == 1 && m.status == MatchStatus.scheduled);
      expect({realR1.entrant1Id, realR1.entrant2Id}, {'e2', 'e3'});
    });

    test('n=5: 3 byes for the top 3 seeds', () {
      final plan = buildSingleElimination(ids(5));
      expect(plan.matches.length, 7); // size 8 → 7 matches
      final byes = plan.matches.where((m) => m.status == MatchStatus.bye).toList();
      expect(byes.length, 3);
      final byeWinners = byes.map((m) => m.winnerEntrantId).toSet();
      expect(byeWinners, {'e1', 'e2', 'e3'});
      // Every real entrant appears exactly once in round 1.
      final inR1 = <String>{};
      for (final m in plan.matches.where((m) => m.roundNumber == 1)) {
        inR1.addAll([m.entrant1Id, m.entrant2Id].whereType<String>());
      }
      expect(inR1, {'e1', 'e2', 'e3', 'e4', 'e5'});
    });

    test('every non-final match has a next match; final has none', () {
      final plan = buildSingleElimination(ids(8));
      final maxRound =
          plan.matches.map((m) => m.roundNumber).reduce((a, b) => a > b ? a : b);
      for (final m in plan.matches) {
        if (m.roundNumber == maxRound) {
          expect(m.nextMatchIdx, isNull);
        } else {
          expect(m.nextMatchIdx, isNotNull);
          expect(m.nextMatchSlot, anyOf(1, 2));
        }
      }
    });
  });

  group('buildRoundRobin', () {
    Set<Set<String>> pairs(List m) =>
        m.map((e) => {e.entrant1Id as String, e.entrant2Id as String}).toSet();

    test('n=4: 6 matches, every pair once, 3 rounds', () {
      final m = buildRoundRobin(ids(4));
      expect(m.length, 6);
      expect(m.map((x) => x.roundNumber).toSet(), {1, 2, 3});
      expect(pairs(m).length, 6); // all distinct
    });

    test('n=3 (odd): 3 matches, every pair once', () {
      final m = buildRoundRobin(ids(3));
      expect(m.length, 3);
      expect(pairs(m), {
        {'e1', 'e2'},
        {'e1', 'e3'},
        {'e2', 'e3'},
      });
    });

    test('n=5 (odd): each of 10 pairs exactly once', () {
      final m = buildRoundRobin(ids(5));
      expect(m.length, 10);
      expect(pairs(m).length, 10);
    });

    test('no match references the bye placeholder (null)', () {
      final m = buildRoundRobin(ids(5));
      expect(m.every((x) => x.entrant1Id != null && x.entrant2Id != null),
          isTrue);
    });
  });

  group('distributeIntoPools', () {
    test('snake distribution spreads top seeds across pools', () {
      final pools = distributeIntoPools(ids(8), 2);
      expect(pools.length, 2);
      // 8 entrants, 2 pools → 4 each.
      expect(pools[0].length, 4);
      expect(pools[1].length, 4);
      // Seed 1 (e1) and seed 2 (e2) land in different pools.
      expect(pools[0].contains('e1'), isTrue);
      expect(pools[1].contains('e2'), isTrue);
    });

    test('every entrant placed exactly once', () {
      final pools = distributeIntoPools(ids(7), 3);
      final all = pools.expand((p) => p).toList();
      expect(all.toSet(), ids(7).toSet());
      expect(all.length, 7);
    });
  });

  group('poolsComplete + buildPlayoffFromPools', () {
    TournamentEntrant ent(String id) => TournamentEntrant(
          id: id,
          divisionId: 'd1',
          teamName: id,
          player1Name: id,
          registeredAt: DateTime(2026),
        );

    TournamentMatch poolMatch(String a, String b, String winner, String pool,
            {MatchStatus status = MatchStatus.completed}) =>
        TournamentMatch(
          id: '$a-$b',
          divisionId: 'd1',
          bracketType: BracketType.pool,
          roundNumber: 1,
          matchNumber: 1,
          poolId: pool,
          entrant1Id: a,
          entrant2Id: b,
          winnerEntrantId: status == MatchStatus.completed ? winner : null,
          status: status,
          createdAt: DateTime(2026),
          games: status == MatchStatus.completed
              ? [
                  MatchGame(
                      id: '$a-$b-g1',
                      matchId: '$a-$b',
                      gameNumber: 1,
                      entrant1Score: winner == a ? 21 : 10,
                      entrant2Score: winner == a ? 10 : 21,
                      winnerEntrantId: winner),
                ]
              : const [],
        );

    test('poolsComplete reflects completion', () {
      final done = [poolMatch('a1', 'a2', 'a1', 'A')];
      expect(poolsComplete(done), isTrue);
      final pending = [
        poolMatch('a1', 'a2', 'a1', 'A', status: MatchStatus.scheduled)
      ];
      expect(poolsComplete(pending), isFalse);
      expect(poolsComplete(const []), isFalse);
    });

    test('seeds playoff from pool winners (2 pools, advance 1)', () {
      final entrants = [ent('a1'), ent('a2'), ent('b1'), ent('b2')];
      final pool = [
        poolMatch('a1', 'a2', 'a1', 'A'),
        poolMatch('b1', 'b2', 'b1', 'B'),
      ];
      final plan = buildPlayoffFromPools(entrants, pool, 1);
      // 2 qualifiers → single final.
      expect(plan.matches.length, 1);
      final m = plan.matches.single;
      expect({m.entrant1Id, m.entrant2Id}, {'a1', 'b1'});
    });

    test('cross-pool seeding avoids same-pool round-1 rematch (advance 2)', () {
      final entrants = [
        ent('a1'), ent('a2'), ent('a3'),
        ent('b1'), ent('b2'), ent('b3'),
      ];
      // Pool A: a1 > a2 > a3 ; Pool B: b1 > b2 > b3.
      final pool = [
        poolMatch('a1', 'a2', 'a1', 'A'),
        poolMatch('a1', 'a3', 'a1', 'A'),
        poolMatch('a2', 'a3', 'a2', 'A'),
        poolMatch('b1', 'b2', 'b1', 'B'),
        poolMatch('b1', 'b3', 'b1', 'B'),
        poolMatch('b2', 'b3', 'b2', 'B'),
      ];
      final plan = buildPlayoffFromPools(entrants, pool, 2);
      // 4 qualifiers (a1,b1,a2,b2) → 3 matches.
      expect(plan.matches.length, 3);
      final r1 = plan.matches.where((m) => m.roundNumber == 1).toList();
      for (final m in r1) {
        final teams = {m.entrant1Id, m.entrant2Id};
        // No first-round match pairs two teams from the same pool.
        final samePoolA = teams.every((t) => t!.startsWith('a'));
        final samePoolB = teams.every((t) => t!.startsWith('b'));
        expect(samePoolA || samePoolB, isFalse,
            reason: 'round-1 match $teams is a same-pool rematch');
      }
    });

    test('isTie=true marks all playoff matches as ties', () {
      final pool = [poolMatch('a1', 'x', 'a1', 'A'), poolMatch('b1', 'y', 'b1', 'B')];
      final plan = buildPlayoffFromPools(
        [ent('a1'), ent('x'), ent('b1'), ent('y')],
        pool,
        1,
        isTie: true,
      );
      expect(plan.matches.every((m) => m.isTie), isTrue,
          reason: 'all playoff matches should be is_tie=true for team divisions');
    });

    test('isTie=false (default) leaves matches as non-ties', () {
      final entrants = [ent('a1'), ent('b1'), ent('x'), ent('y')];
      final pool = [poolMatch('a1', 'x', 'a1', 'A'), poolMatch('b1', 'y', 'b1', 'B')];
      final plan = buildPlayoffFromPools(entrants, pool, 1);
      expect(plan.matches.every((m) => !m.isTie), isTrue);
    });
  });

  group('pairSubmatches (team ties)', () {
    const tc3 = TieConfig(submatchCount: 3, pairingRule: PairingRule.sameRank);
    test('same_rank pairs by position', () {
      final pairs = pairSubmatches(['a1', 'a2', 'a3'], ['b1', 'b2', 'b3'], tc3);
      expect(pairs.length, 3);
      expect(pairs[0], (position: 1, side1: 'a1', side2: 'b1'));
      expect(pairs[2], (position: 3, side1: 'a3', side2: 'b3'));
    });

    test('same_rank limited by submatchCount', () {
      const tc2 = TieConfig(submatchCount: 2, pairingRule: PairingRule.sameRank);
      final pairs = pairSubmatches(['a1', 'a2', 'a3'], ['b1', 'b2', 'b3'], tc2);
      expect(pairs.length, 2);
    });

    test('same_rank limited by the shorter roster', () {
      final pairs = pairSubmatches(['a1', 'a2', 'a3'], ['b1', 'b2'], tc3);
      expect(pairs.length, 2);
    });

    test('manual yields unpaired positioned slots', () {
      const tcm = TieConfig(submatchCount: 3, pairingRule: PairingRule.manual);
      final pairs = pairSubmatches(['a1'], ['b1'], tcm);
      expect(pairs.length, 3);
      expect(pairs.every((p) => p.side1 == null && p.side2 == null), isTrue);
      expect(pairs.map((p) => p.position), [1, 2, 3]);
    });
  });

  group('size guard (estimateMatchCount + buildBracketPlan cap)', () {
    TournamentDivision div(DivisionFormat f,
            {int? poolCount, int? advancePerPool}) =>
        TournamentDivision(
          id: 'd1',
          eventId: 'e1',
          name: 'D',
          sport: 'Badminton',
          discipline: Discipline.singles,
          skillLevel: 'C',
          format: f,
          scoringConfig: ScoringConfig.defaultFor('badminton'),
          teamSize: 1,
          poolCount: poolCount,
          advancePerPool: advancePerPool,
          createdAt: DateTime(2026),
        );

    test('estimateMatchCount per format', () {
      expect(estimateMatchCount(div(DivisionFormat.singleElimination), 8), 7);
      expect(estimateMatchCount(div(DivisionFormat.singleElimination), 100), 127);
      expect(estimateMatchCount(div(DivisionFormat.roundRobin), 100), 4950);
      // Round-robin of thousands is millions.
      expect(estimateMatchCount(div(DivisionFormat.roundRobin), 2000), 1999000);
      expect(estimateMatchCount(div(DivisionFormat.custom), 5000), 0);
    });

    test('buildBracketPlan throws TooManyMatchesError for huge round-robin', () {
      final ids = List.generate(2000, (i) => 'e$i');
      expect(() => buildBracketPlan(div(DivisionFormat.roundRobin), ids),
          throwsA(isA<TooManyMatchesError>()));
    });

    test('buildBracketPlan allows a large-but-bounded single-elim', () {
      final ids = List.generate(1000, (i) => 'e$i'); // ~1023 matches < 4096
      final plan = buildBracketPlan(div(DivisionFormat.singleElimination), ids);
      expect(plan.matches.length, lessThanOrEqualTo(kMaxBracketMatches));
      expect(plan.matches.isNotEmpty, isTrue);
    });
  });

  group('buildBracketPlan dispatch', () {
    TournamentDivision div(DivisionFormat f,
            {int? poolCount, EntrantKind kind = EntrantKind.individual}) =>
        TournamentDivision(
          id: 'd1',
          eventId: 'e1',
          name: 'D',
          sport: 'Badminton',
          discipline: Discipline.singles,
          skillLevel: 'C',
          format: f,
          scoringConfig: ScoringConfig.defaultFor('badminton'),
          teamSize: 1,
          entrantKind: kind,
          poolCount: poolCount,
          createdAt: DateTime(2026),
        );

    test('team division marks every match as a tie', () {
      final plan = buildBracketPlan(
          div(DivisionFormat.singleElimination, kind: EntrantKind.team),
          ids(4));
      expect(plan.matches.isNotEmpty, isTrue);
      expect(plan.matches.every((m) => m.isTie), isTrue);
      // Individual division does not.
      final indiv = buildBracketPlan(
          div(DivisionFormat.singleElimination), ids(4));
      expect(indiv.matches.every((m) => !m.isTie), isTrue);
    });

    test('round robin', () {
      final plan = buildBracketPlan(div(DivisionFormat.roundRobin), ids(4));
      expect(plan.matches.length, 6);
    });

    test('single elimination', () {
      final plan =
          buildBracketPlan(div(DivisionFormat.singleElimination), ids(4));
      expect(plan.matches.length, 3);
    });

    test('pools playoff builds pool matches tagged with pool ids', () {
      final plan = buildBracketPlan(
          div(DivisionFormat.poolsPlayoff, poolCount: 2), ids(6));
      expect(plan.matches.every((m) => m.bracketType == BracketType.pool),
          isTrue);
      expect(plan.matches.map((m) => m.poolId).toSet(), {'A', 'B'});
    });
  });
}
