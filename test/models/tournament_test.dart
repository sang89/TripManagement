import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/tournament.dart';

void main() {
  group('enum fromString/dbValue round-trip', () {
    test('Discipline + teamSize', () {
      for (final v in Discipline.values) {
        expect(Discipline.fromString(v.dbValue), v);
      }
      expect(Discipline.singles.teamSize, 1);
      expect(Discipline.doubles.teamSize, 2);
      expect(Discipline.mixed.teamSize, 2);
    });

    test('DivisionFormat', () {
      for (final v in DivisionFormat.values) {
        expect(DivisionFormat.fromString(v.dbValue), v);
      }
      expect(DivisionFormat.fromString('round_robin'), DivisionFormat.roundRobin);
      expect(DivisionFormat.fromString('pools_playoff'),
          DivisionFormat.poolsPlayoff);
    });

    test('ScoringSystem / DivisionStatus / EntrantStatus / MatchStatus / '
        'BracketType / CourtStatus', () {
      for (final v in ScoringSystem.values) {
        expect(ScoringSystem.fromString(v.dbValue), v);
      }
      for (final v in DivisionStatus.values) {
        expect(DivisionStatus.fromString(v.dbValue), v);
      }
      for (final v in EntrantStatus.values) {
        expect(EntrantStatus.fromString(v.dbValue), v);
      }
      for (final v in MatchStatus.values) {
        expect(MatchStatus.fromString(v.dbValue), v);
      }
      for (final v in BracketType.values) {
        expect(BracketType.fromString(v.dbValue), v);
      }
      for (final v in CourtStatus.values) {
        expect(CourtStatus.fromString(v.dbValue), v);
      }
    });
  });

  group('ScoringConfig', () {
    test('defaultFor known sports vs free-form custom', () {
      final bad = ScoringConfig.defaultFor('badminton');
      expect(bad.sport, 'Badminton');
      expect(bad.system, ScoringSystem.rally);
      expect(bad.pointsToWin, 21);
      expect(bad.cap, 30);
      expect(bad.bestOf, 3);
      expect(bad.gamesToWin, 2);

      final pkl = ScoringConfig.defaultFor('pickleball');
      expect(pkl.system, ScoringSystem.sideOut);
      expect(pkl.pointsToWin, 11);
      expect(pkl.cap, isNull);

      // Free-form sport keeps its label and gets a generic rally default.
      final tennis = ScoringConfig.defaultFor('Tennis');
      expect(tennis.sport, 'Tennis');
      expect(tennis.pointsToWin, 21);
      expect(tennis.cap, isNull);
      // Empty falls back to "Custom".
      expect(ScoringConfig.defaultFor('').sport, 'Custom');
    });

    test('toJson/fromJson round-trip preserves free-form sport', () {
      final cfg = ScoringConfig.defaultFor('badminton');
      final restored = ScoringConfig.fromJson(cfg.toJson());
      expect(restored.sport, 'Badminton');
      expect(restored.system, cfg.system);
      expect(restored.pointsToWin, cfg.pointsToWin);
      expect(restored.cap, cfg.cap);
      expect(restored.bestOf, cfg.bestOf);
    });

    test('custom scoring config round-trips', () {
      const custom = ScoringConfig(
        sport: 'Squash',
        system: ScoringSystem.rally,
        pointsToWin: 15,
        winByTwo: false,
        cap: null,
        bestOf: 5,
      );
      final r = ScoringConfig.fromJson(custom.toJson());
      expect(r.sport, 'Squash');
      expect(r.pointsToWin, 15);
      expect(r.winByTwo, isFalse);
      expect(r.bestOf, 5);
    });

    test('toJson omits cap when null; copyWith can clear cap', () {
      final pkl = ScoringConfig.defaultFor('pickleball');
      expect(pkl.toJson().containsKey('cap'), isFalse);

      final capped = pkl.copyWith(cap: 15);
      expect(capped.cap, 15);
      expect(capped.copyWith(clearCap: true).cap, isNull);
    });
  });

  group('TournamentDivision', () {
    Map<String, dynamic> json() => {
          'id': 'd1',
          'event_id': 'e1',
          'name': 'Men\'s Doubles B',
          'sport': 'Badminton',
          'discipline': 'doubles',
          'skill_level': 'B',
          'format': 'single_elimination',
          'scoring_config': ScoringConfig.defaultFor('badminton').toJson(),
          'team_size': 2,
          'entrant_cap': 16,
          'status': 'registration',
          'entrant_count': 5,
          'match_count': 0,
          'completed_match_count': 0,
          'created_at': '2026-06-22T10:00:00Z',
        };

    test('fromJson parses fields', () {
      final d = TournamentDivision.fromJson(json());
      expect(d.discipline, Discipline.doubles);
      expect(d.sport, 'Badminton');
      expect(d.skillLevel, 'B');
      expect(d.format, DivisionFormat.singleElimination);
      expect(d.teamSize, 2);
      expect(d.entrantCap, 16);
      expect(d.entrantCount, 5);
      expect(d.registrationOpen, isTrue);
      expect(d.bracketGenerated, isFalse);
    });

    test('registrationOpen false once bracket generated', () {
      final d = TournamentDivision.fromJson(
          {...json(), 'bracket_generated_at': '2026-06-22T12:00:00Z'});
      expect(d.bracketGenerated, isTrue);
      expect(d.registrationOpen, isFalse);
    });

    test('copyWithCounts preserves config', () {
      final d = TournamentDivision.fromJson(json());
      final c = d.copyWithCounts(entrantCount: 9, completedMatchCount: 2);
      expect(c.entrantCount, 9);
      expect(c.completedMatchCount, 2);
      expect(c.name, d.name);
      expect(c.format, d.format);
    });

    test('copyWith clearEntrantCap and clearBracketGeneratedAt', () {
      final d = TournamentDivision.fromJson(
          {...json(), 'bracket_generated_at': '2026-06-22T12:00:00Z'});
      expect(d.copyWith(clearEntrantCap: true).entrantCap, isNull);
      expect(d.copyWith(clearBracketGeneratedAt: true).bracketGeneratedAt,
          isNull);
      // Setting still works.
      expect(d.copyWith(entrantCap: 8).entrantCap, 8);
    });
  });

  group('TournamentTemplate (M9)', () {
    test('fromJson parses config bundle', () {
      final t = TournamentTemplate.fromJson({
        'id': 't1',
        'name': 'Team Ties',
        'config': {
          'sport': 'Badminton',
          'entrant_kind': 'team',
          'roster_size': 5,
          'tie_config': const TieConfig(submatchCount: 5).toJson(),
        },
      });
      expect(t.name, 'Team Ties');
      expect(t.config['entrant_kind'], 'team');
      expect(t.config['roster_size'], 5);
    });
  });

  group('Team rosters (M6)', () {
    test('EntrantKind round-trip + default', () {
      expect(EntrantKind.fromString('team'), EntrantKind.team);
      expect(EntrantKind.fromString('individual'), EntrantKind.individual);
      expect(EntrantKind.fromString(null), EntrantKind.individual);
      expect(EntrantKind.team.dbValue, 'team');
    });

    test('TieConfig round-trip', () {
      const t = TieConfig(
          submatchCount: 5, pairingRule: PairingRule.manual, winThreshold: 3);
      final r = TieConfig.fromJson(t.toJson());
      expect(r.submatchCount, 5);
      expect(r.pairingRule, PairingRule.manual);
      expect(r.winThreshold, 3);
    });

    test('division parses entrant_kind, roster_size, tie_config', () {
      final d = TournamentDivision.fromJson({
        'id': 'd1',
        'event_id': 'e1',
        'name': 'Club Teams',
        'sport': 'Badminton',
        'discipline': 'singles',
        'skill_level': '',
        'format': 'single_elimination',
        'scoring_config': ScoringConfig.defaultFor('badminton').toJson(),
        'team_size': 1,
        'entrant_kind': 'team',
        'roster_size': 10,
        'tie_config': const TieConfig(submatchCount: 5, winThreshold: 3).toJson(),
        'created_at': '2026-06-23T10:00:00Z',
      });
      expect(d.entrantKind, EntrantKind.team);
      expect(d.rosterSize, 10);
      expect(d.tieConfig?.submatchCount, 5);
      expect(d.tieConfig?.winThreshold, 3);
    });

    test('team entrant parses ranked roster (sorted) + isTeam + userIds', () {
      final e = TournamentEntrant.fromJson({
        'id': 'en1',
        'division_id': 'd1',
        'team_name': 'Team A',
        'player1_name': 'Captain',
        'status': 'registered',
        'registered_at': '2026-06-23T10:00:00Z',
        'tournament_entrant_players': [
          {'id': 'p2', 'entrant_id': 'en1', 'name': 'Bob', 'player_rank': 2,
            'sort_order': 1, 'user_id': 'u2'},
          {'id': 'p1', 'entrant_id': 'en1', 'name': 'Alice', 'player_rank': 1,
            'sort_order': 0, 'user_id': 'u1'},
        ],
      });
      expect(e.isTeam, isTrue);
      expect(e.players.map((p) => p.name), ['Alice', 'Bob']); // sorted by order
      expect(e.userIds, containsAll(['u1', 'u2']));
    });
  });

  group('TournamentEntrant', () {
    final singles = TournamentEntrant.fromJson({
      'id': 'en1',
      'division_id': 'd1',
      'team_name': 'Alice',
      'player1_name': 'Alice',
      'status': 'registered',
      'registered_at': '2026-06-22T10:00:00Z',
    });
    final doubles = TournamentEntrant.fromJson({
      'id': 'en2',
      'division_id': 'd1',
      'team_name': 'A/B',
      'player1_name': 'Alice',
      'player1_user_id': 'u1',
      'player2_name': 'Bob',
      'player2_user_id': 'u2',
      'seed': 3,
      'status': 'registered',
      'registered_at': '2026-06-22T10:00:00Z',
    });

    test('isDoubles / userIds', () {
      expect(singles.isDoubles, isFalse);
      expect(doubles.isDoubles, isTrue);
      expect(singles.userIds, isEmpty);
      expect(doubles.userIds, ['u1', 'u2']);
    });

    test('copyWith clearSeed / clearPoolId / clearPlayer2 / status', () {
      expect(doubles.copyWith(clearSeed: true).seed, isNull);
      expect(doubles.copyWith(seed: 1).seed, 1);
      expect(doubles.copyWith(poolId: 'A').poolId, 'A');
      expect(doubles.copyWith(poolId: 'A').copyWith(clearPoolId: true).poolId,
          isNull);
      final cleared = doubles.copyWith(clearPlayer2: true);
      expect(cleared.player2Name, isNull);
      expect(cleared.player2UserId, isNull);
      expect(doubles.copyWith(status: EntrantStatus.withdrawn).isWithdrawn,
          isTrue);
    });
  });

  group('TournamentMatch + MatchGame', () {
    final match = TournamentMatch.fromJson({
      'id': 'm1',
      'division_id': 'd1',
      'bracket_type': 'winners',
      'round_number': 1,
      'match_number': 2,
      'entrant1_id': 'en1',
      'entrant2_id': 'en2',
      'next_match_id': 'm5',
      'next_match_slot': 1,
      'status': 'scheduled',
      'created_at': '2026-06-22T10:00:00Z',
      'tournament_match_games': [
        {
          'id': 'g2',
          'match_id': 'm1',
          'game_number': 2,
          'entrant1_score': 21,
          'entrant2_score': 18,
          'winner_entrant_id': 'en1',
        },
        {
          'id': 'g1',
          'match_id': 'm1',
          'game_number': 1,
          'entrant1_score': 19,
          'entrant2_score': 21,
          'winner_entrant_id': 'en2',
        },
      ],
    });

    test('nested games parsed and sorted by gameNumber', () {
      expect(match.games.length, 2);
      expect(match.games.first.gameNumber, 1);
      expect(match.games.last.gameNumber, 2);
    });

    test('isReady true when both entrants set and not completed', () {
      expect(match.isReady, isTrue);
      expect(match.isBye, isFalse);
    });

    test('copyWith clear flags', () {
      expect(match.copyWith(clearEntrant1: true).entrant1Id, isNull);
      expect(match.copyWith(clearEntrant2: true).entrant2Id, isNull);
      expect(
          match.copyWith(winnerEntrantId: 'en1').winnerEntrantId, 'en1');
      expect(
          match
              .copyWith(winnerEntrantId: 'en1')
              .copyWith(clearWinner: true)
              .winnerEntrantId,
          isNull);
      expect(match.copyWith(courtId: 'c1').courtId, 'c1');
      expect(match.copyWith(courtId: 'c1').copyWith(clearCourt: true).courtId,
          isNull);
    });

    test('preserves nextMatch plumbing through copyWith', () {
      final c = match.copyWith(status: MatchStatus.completed);
      expect(c.nextMatchId, 'm5');
      expect(c.nextMatchSlot, 1);
    });

    test('MatchGame toJson shape', () {
      final g = match.games.first;
      final json = g.toJson();
      expect(json['game_number'], 1);
      expect(json['entrant1_score'], 19);
      expect(json['entrant2_score'], 21);
    });

    test('time fields parse from JSON as UTC DateTimes', () {
      final m = TournamentMatch.fromJson({
        'id': 'm2',
        'division_id': 'd1',
        'round_number': 1,
        'match_number': 1,
        'status': 'in_progress',
        'created_at': '2026-06-24T09:00:00Z',
        'scheduled_at': '2026-06-24T10:00:00Z',
        'started_at': '2026-06-24T10:05:00Z',
        'ended_at': null,
        'estimated_duration_minutes': 45,
      });
      expect(m.scheduledAt, DateTime.utc(2026, 6, 24, 10, 0, 0));
      expect(m.startedAt, DateTime.utc(2026, 6, 24, 10, 5, 0));
      expect(m.endedAt, isNull);
      expect(m.estimatedDurationMinutes, 45);
    });

    test('isWalkover and isDecided cover walkover matches', () {
      TournamentMatch make(String status) => TournamentMatch.fromJson({
            'id': 'mx',
            'division_id': 'd1',
            'round_number': 1,
            'match_number': 1,
            'status': status,
            'entrant1_id': 'e1',
            'entrant2_id': 'e2',
            'created_at': '2026-06-24T09:00:00Z',
          });
      final wo = make('walkover');
      expect(wo.isWalkover, isTrue);
      expect(wo.isDecided, isTrue);
      expect(wo.isReady, isFalse,
          reason: 'walkover match should not be re-scoreable');

      final comp = make('completed');
      expect(comp.isWalkover, isFalse);
      expect(comp.isDecided, isTrue);

      final bye = make('bye');
      expect(bye.isDecided, isTrue);

      final pending = make('pending');
      expect(pending.isDecided, isFalse);
    });

    test('isLive is true when started and not ended', () {
      final started = TournamentMatch.fromJson({
        'id': 'm3',
        'division_id': 'd1',
        'round_number': 1,
        'match_number': 1,
        'status': 'in_progress',
        'created_at': '2026-06-24T09:00:00Z',
        'started_at': '2026-06-24T10:00:00Z',
      });
      expect(started.isLive, isTrue);
      expect(started.elapsed, isNotNull);

      final notStarted = TournamentMatch.fromJson({
        'id': 'm4',
        'division_id': 'd1',
        'round_number': 1,
        'match_number': 1,
        'status': 'pending',
        'created_at': '2026-06-24T09:00:00Z',
      });
      expect(notStarted.isLive, isFalse);
      expect(notStarted.elapsed, isNull);

      final ended = TournamentMatch.fromJson({
        'id': 'm5',
        'division_id': 'd1',
        'round_number': 1,
        'match_number': 1,
        'status': 'completed',
        'created_at': '2026-06-24T09:00:00Z',
        'started_at': '2026-06-24T10:00:00Z',
        'ended_at': '2026-06-24T10:30:00Z',
      });
      expect(ended.isLive, isFalse);
    });

    // Regression: isLive must be status-based, not timestamp-based.
    //
    // Before the fix, isLive was `startedAt != null && endedAt == null`.
    // This meant a match that was stopped (started_at cleared → status back
    // to 'scheduled') would still look live in the model if the raw update
    // was stale, and a completed match with a missing ended_at would show
    // the "Stop match" tile.
    //
    // Fix: isLive = status == MatchStatus.inProgress.
    test('isLive is false for scheduled match even when started_at is set '
        '(stop-match regression)', () {
      final stopped = TournamentMatch.fromJson({
        'id': 'ms',
        'division_id': 'd1',
        'round_number': 1,
        'match_number': 1,
        'status': 'scheduled',
        'created_at': '2026-06-24T09:00:00Z',
        'started_at': '2026-06-24T10:00:00Z', // stale — stopMatch cleared it
      });
      expect(stopped.isLive, isFalse,
          reason: 'stopped match (status=scheduled) must not show as live '
              'even if started_at was not yet cleared in the local cache');
    });

    test('isLive is true for in_progress match even when started_at is null '
        '(status is the source of truth)', () {
      final live = TournamentMatch.fromJson({
        'id': 'ml',
        'division_id': 'd1',
        'round_number': 1,
        'match_number': 1,
        'status': 'in_progress',
        'created_at': '2026-06-24T09:00:00Z',
        // started_at absent — DB not yet refreshed after startMatch
      });
      expect(live.isLive, isTrue,
          reason: 'in_progress status is the canonical live signal');
    });

    // Regression: "Assign to court" must be hidden for decided matches.
    //
    // Before the fix, a completed match (both entrants set, not a walkover)
    // passed the canScore check and showed the "Assign to court" action tile.
    // Tapping it called assign_match_to_court which threw match_not_assignable,
    // surfacing as a generic "Could not assign the court." snackbar.
    //
    // Fix: the tile condition is now `court == null && !match.isDecided`.
    // This test guards the model predicates that feed that condition.
    test('isDecided blocks court assignment for all three decided statuses', () {
      TournamentMatch make(String status) => TournamentMatch.fromJson({
            'id': 'mx',
            'division_id': 'd1',
            'round_number': 1,
            'match_number': 1,
            'status': status,
            'entrant1_id': 'e1',
            'entrant2_id': 'e2',
            'created_at': '2026-06-24T09:00:00Z',
          });

      // All three decided statuses must block the "Assign to court" tile.
      for (final status in ['completed', 'walkover', 'bye']) {
        final m = make(status);
        expect(m.isDecided, isTrue,
            reason: 'status=$status should be decided; '
                '"Assign to court" must not appear');
        // The tile guard: court == null && !match.isDecided
        // With isDecided=true the guard is false regardless of court.
        expect(!m.isDecided, isFalse,
            reason: 'tile guard !isDecided must be false for status=$status');
      }

      // Non-decided statuses with both entrants set should allow assignment.
      for (final status in ['pending', 'scheduled', 'in_progress']) {
        final m = make(status);
        expect(m.isDecided, isFalse,
            reason: 'status=$status should allow "Assign to court"');
      }
    });

    test('copyWith clears time fields', () {
      final base = TournamentMatch.fromJson({
        'id': 'm6',
        'division_id': 'd1',
        'round_number': 1,
        'match_number': 1,
        'status': 'in_progress',
        'created_at': '2026-06-24T09:00:00Z',
        'scheduled_at': '2026-06-24T10:00:00Z',
        'started_at': '2026-06-24T10:05:00Z',
        'estimated_duration_minutes': 30,
      });
      expect(base.copyWith(clearScheduledAt: true).scheduledAt, isNull);
      expect(base.copyWith(clearStartedAt: true).startedAt, isNull);
      expect(base.copyWith(clearEstimatedDuration: true).estimatedDurationMinutes, isNull);
      expect(
          base.copyWith(estimatedDurationMinutes: 60).estimatedDurationMinutes,
          60);
    });
  });

  group('TieSubmatch + tie match (M7)', () {
    test('TieSubmatch parses games, winner side, readiness', () {
      final s = TieSubmatch.fromJson({
        'id': 's1',
        'tie_match_id': 'm1',
        'position': 2,
        'side1_player_id': 'p1',
        'side2_player_id': 'p2',
        'games': [
          {'side1_score': 21, 'side2_score': 15},
          {'side1_score': 19, 'side2_score': 21},
          {'side1_score': 21, 'side2_score': 10},
        ],
        'winner_side': 1,
        'status': 'completed',
      });
      expect(s.position, 2);
      expect(s.games.length, 3);
      expect(s.games.first.side1, 21);
      expect(s.games.first.side2, 15);
      expect(s.winnerSide, 1);
      expect(s.isCompleted, isTrue);
      expect(s.isReady, isTrue);
    });

    test('unassigned manual sub-match is not ready', () {
      final s = TieSubmatch.fromJson({
        'id': 's2',
        'tie_match_id': 'm1',
        'position': 1,
        'status': 'scheduled',
      });
      expect(s.isReady, isFalse);
      expect(s.isCompleted, isFalse);
      expect(s.games, isEmpty);
    });

    test('match parses is_tie + nested sub-matches (sorted by position)', () {
      final m = TournamentMatch.fromJson({
        'id': 'm1',
        'division_id': 'd1',
        'round_number': 1,
        'match_number': 1,
        'entrant1_id': 'A',
        'entrant2_id': 'B',
        'status': 'scheduled',
        'is_tie': true,
        'created_at': '2026-06-23T10:00:00Z',
        'tournament_tie_submatches': [
          {'id': 's2', 'tie_match_id': 'm1', 'position': 2, 'status': 'scheduled'},
          {'id': 's1', 'tie_match_id': 'm1', 'position': 1, 'status': 'scheduled'},
        ],
      });
      expect(m.isTie, isTrue);
      expect(m.submatches.length, 2);
      expect(m.submatches.map((s) => s.position), [1, 2]); // sorted
    });

    test('non-tie match defaults isTie=false with no sub-matches', () {
      final m = TournamentMatch.fromJson({
        'id': 'm2',
        'division_id': 'd1',
        'round_number': 1,
        'match_number': 1,
        'status': 'scheduled',
        'created_at': '2026-06-23T10:00:00Z',
      });
      expect(m.isTie, isFalse);
      expect(m.submatches, isEmpty);
    });
  });

  group('Court', () {
    final court = Court.fromJson({
      'id': 'c1',
      'event_id': 'e1',
      'name': 'Court 1',
      'status': 'in_use',
      'current_match_id': 'm1',
      'sort_order': 1,
    });

    test('fromJson + isAvailable', () {
      expect(court.name, 'Court 1');
      expect(court.status, CourtStatus.inUse);
      expect(court.isAvailable, isFalse);
      expect(court.currentMatchId, 'm1');
    });

    test('copyWith clearCurrentMatch', () {
      expect(court.copyWith(clearCurrentMatch: true).currentMatchId, isNull);
      expect(court.copyWith(status: CourtStatus.available).isAvailable, isTrue);
    });
  });

  // ── DraftEntrant ─────────────────────────────────────────────────────────────
  group('DraftEntrant', () {
    const draft = DraftEntrant(
      localId: 'local-1',
      teamName: 'Team Alpha',
      player1Name: 'Alice',
      player2Name: 'Bob',
    );

    test('copyWith updates fields', () {
      final updated = draft.copyWith(teamName: 'Team Beta');
      expect(updated.teamName, 'Team Beta');
      expect(updated.player1Name, 'Alice');
      expect(updated.player2Name, 'Bob');
      expect(updated.localId, 'local-1');
    });

    test('copyWith preserves localId', () {
      expect(draft.copyWith(player2Name: null).localId, 'local-1');
    });
  });

  // ── BracketSegmentConfig ──────────────────────────────────────────────────────
  group('BracketSegmentConfig', () {
    final scoring = ScoringConfig.defaultFor('Badminton');
    final seg = BracketSegmentConfig(
      localId: 'seg-1',
      name: 'Elite',
      entrants: const [],
      format: DivisionFormat.singleElimination,
      scoringConfig: scoring,
      poolCount: null,
      advancePerPool: null,
    );

    test('copyWith name', () {
      expect(seg.copyWith(name: 'Open').name, 'Open');
      expect(seg.copyWith(name: 'Open').localId, 'seg-1');
    });

    test('copyWith format', () {
      final updated = seg.copyWith(format: DivisionFormat.roundRobin);
      expect(updated.format, DivisionFormat.roundRobin);
    });

    test('copyWith clearPoolCount sets null', () {
      final withPool = seg.copyWith(poolCount: 4, advancePerPool: 2);
      expect(withPool.poolCount, 4);
      final cleared = withPool.copyWith(clearPoolCount: true);
      expect(cleared.poolCount, isNull);
    });

    test('copyWith entrants', () {
      const e = DraftEntrant(
          localId: 'e1', teamName: 'A', player1Name: 'A');
      final updated = seg.copyWith(entrants: [e]);
      expect(updated.entrants.length, 1);
      expect(updated.entrants.first.localId, 'e1');
    });
  });
}
