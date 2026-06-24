import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/tournament.dart';
import 'package:trip_management/utils/court_logic.dart';

void main() {
  TournamentMatch m(
    String id, {
    String? court,
    int? order,
    String? e1 = 'x',
    String? e2 = 'y',
    MatchStatus status = MatchStatus.scheduled,
  }) =>
      TournamentMatch(
        id: id,
        divisionId: 'd1',
        roundNumber: 1,
        matchNumber: 1,
        entrant1Id: e1,
        entrant2Id: e2,
        courtId: court,
        scheduledOrder: order,
        status: status,
        createdAt: DateTime(2026),
      );

  group('courtQueue', () {
    test('returns court matches ordered, completed excluded', () {
      final all = [
        m('a', court: 'c1', order: 2),
        m('b', court: 'c1', order: 1),
        m('c', court: 'c1', order: 3, status: MatchStatus.completed),
        m('d', court: 'c2', order: 1),
        m('e'), // unassigned
      ];
      final q = courtQueue(all, 'c1');
      expect(q.map((x) => x.id), ['b', 'a']); // ordered, completed 'c' excluded
    });

    test('null order sorts last', () {
      final all = [
        m('a', court: 'c1'), // null order
        m('b', court: 'c1', order: 1),
      ];
      expect(courtQueue(all, 'c1').map((x) => x.id), ['b', 'a']);
    });
  });

  group('doubleBookedEntrants', () {
    test('flags a player on two active courts', () {
      final all = [
        m('a', court: 'c1', e1: 'alice', e2: 'bob'),
        m('b', court: 'c2', e1: 'alice', e2: 'carol'), // alice double-booked
        m('c', court: 'c3', e1: 'dave', e2: 'erin'),
      ];
      expect(doubleBookedEntrants(all), {'alice'});
    });

    test('ignores unassigned and completed matches', () {
      final all = [
        m('a', court: 'c1', e1: 'alice', e2: 'bob'),
        m('b', e1: 'alice', e2: 'carol'), // unassigned — not a conflict
        m('c', court: 'c2', e1: 'alice', e2: 'dave', status: MatchStatus.completed),
      ];
      expect(doubleBookedEntrants(all), isEmpty);
    });
  });

  group('unassignedReady', () {
    test('only ready matches without a court', () {
      final all = [
        m('a'), // ready, no court
        m('b', court: 'c1'), // assigned
        m('c', e2: null), // not ready (missing team)
        m('d', status: MatchStatus.completed), // completed
        m('e', status: MatchStatus.bye), // bye not ready
      ];
      expect(unassignedReady(all).map((x) => x.id), ['a']);
    });
  });
}
