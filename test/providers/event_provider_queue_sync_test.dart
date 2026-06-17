// ignore_for_file: avoid_dynamic_calls
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/event.dart';
import 'package:trip_management/models/event_guest.dart';
import 'package:trip_management/providers/event_provider.dart';

// ─── Test helpers ──────────────────────────────────────────────────────────────

Event _event({
  String id = 'ev1',
  String createdBy = 'organizer',
  List<EventGuest> guests = const [],
}) =>
    Event(
      id: id,
      createdBy: createdBy,
      title: 'Badminton',
      description: '',
      location: '',
      startAt: DateTime(2026, 8, 1),
      inviteCode: 'code',
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
      eventType: EventType.signup,
      guests: guests,
    );

EventGuest _guest({
  required String id,
  required String userId,
  String displayName = '',
  String status = 'going',
}) =>
    EventGuest(
      id: id,
      eventId: 'ev1',
      userId: userId,
      displayName: displayName.isEmpty ? 'User $userId' : displayName,
      status: status,
      rsvpAt: DateTime(2026, 6, 1),
      createdAt: DateTime(2026, 6, 1),
    );

Map<String, dynamic> _activityRow({
  String id = 'act1',
  String sessionId = 'sess1',
  String eventId = 'ev1',
  int spots = 4,
  int sortOrder = 1,
  int playingCount = 0,
  bool allowDuplicates = false,
}) =>
    {
      'id': id,
      'session_id': sessionId,
      'event_id': eventId,
      'name': 'Court 1',
      'players_per_round': spots,
      'max_rounds': null,
      'current_round': 0,
      'status': 'active',
      'waiting_count': 0,
      'playing_count': playingCount,
      'sort_order': sortOrder,
      'allow_duplicates': allowDuplicates,
      'created_by': 'organizer',
      'created_at': '2026-06-16T00:00:00Z',
    };

Map<String, dynamic> _entryRow({
  String id = 'entry1',
  String activityId = 'act1',
  String? userId = 'user1',
  String displayName = 'Alice',
  int queuePosition = 1,
}) =>
    {
      'id': id,
      'activity_id': activityId,
      'user_id': userId,
      'display_name': displayName,
      'avatar_url': null,
      'status': 'playing',
      'queue_position': queuePosition,
      'rounds_played': 0,
      'joined_at': '2026-06-16T00:00:00Z',
    };

// ─── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Activity INSERT ─────────────────────────────────────────────────────────

  group('handleQueueActivityInsert', () {
    test('adds activity to _sessionQueues and initialises _queueEntries', () {
      final p = EventProvider();
      p.handleQueueActivityInsert(_activityRow());

      expect(p.queuesFor('sess1').length, 1);
      expect(p.queuesFor('sess1').first.id, 'act1');
      expect(p.entriesFor('act1'), isEmpty);
    });

    test('sorts multiple activities by sortOrder', () {
      final p = EventProvider();
      p.handleQueueActivityInsert(_activityRow(id: 'act2', sortOrder: 2));
      p.handleQueueActivityInsert(_activityRow(id: 'act1', sortOrder: 1));

      final ids = p.queuesFor('sess1').map((a) => a.id).toList();
      expect(ids, ['act1', 'act2']);
    });

    test('is idempotent — duplicate INSERT is ignored', () {
      final p = EventProvider();
      p.handleQueueActivityInsert(_activityRow());
      p.handleQueueActivityInsert(_activityRow()); // duplicate

      expect(p.queuesFor('sess1').length, 1);
    });

    test('recomputes free pool after INSERT (no entries yet → everyone free)', () {
      final p = EventProvider();
      p.seedEventsForTest([
        _event(guests: [_guest(id: 'g1', userId: 'u1')]),
      ]);
      p.handleQueueActivityInsert(_activityRow());

      expect(p.freePoolFor('sess1').length, 1);
    });
  });

  // ── Activity UPDATE ─────────────────────────────────────────────────────────

  group('handleQueueActivityUpdate', () {
    test('updates sort_order and re-sorts list', () {
      final p = EventProvider();
      p.handleQueueActivityInsert(_activityRow(id: 'act1', sortOrder: 1));
      p.handleQueueActivityInsert(_activityRow(id: 'act2', sortOrder: 2));

      // Simulate clear_queue rotating act1 to the bottom
      p.handleQueueActivityUpdate(_activityRow(id: 'act1', sortOrder: 3));

      final ids = p.queuesFor('sess1').map((a) => a.id).toList();
      expect(ids, ['act2', 'act1']);
    });

    test('recomputes free pool via secondary trigger signal', () {
      final p = EventProvider();
      p.seedEventsForTest([
        _event(guests: [
          _guest(id: 'g1', userId: 'u1'),
          _guest(id: 'g2', userId: 'u2'),
        ]),
      ]);
      p.handleQueueActivityInsert(_activityRow());
      // Simulate u1 joining a queue (entry already added)
      p.handleQueueEntryInsert(_entryRow(userId: 'u1'));

      // Before trigger UPDATE, u1 is already excluded by entry INSERT
      expect(p.freePoolFor('sess1').any((e) => e.userId == 'u1'), isFalse);

      // Activity UPDATE (playing_count trigger) should keep free pool consistent
      p.handleQueueActivityUpdate(_activityRow(playingCount: 1));
      expect(p.freePoolFor('sess1').any((e) => e.userId == 'u1'), isFalse);
      expect(p.freePoolFor('sess1').any((e) => e.userId == 'u2'), isTrue);
    });

    test('handles UPDATE for unknown session gracefully (no throw)', () {
      final p = EventProvider();
      // Act with no prior state seeded
      expect(
        () => p.handleQueueActivityUpdate(_activityRow()),
        returnsNormally,
      );
    });
  });

  // ── Activity DELETE ─────────────────────────────────────────────────────────

  group('handleQueueActivityDelete', () {
    test('removes activity and its entries from cache', () {
      final p = EventProvider();
      p.handleQueueActivityInsert(_activityRow());
      p.handleQueueEntryInsert(_entryRow());

      p.handleQueueActivityDelete(_activityRow());

      expect(p.queuesFor('sess1'), isEmpty);
      expect(p.entriesFor('act1'), isEmpty);
    });

    test('restores deleted-queue members to free pool', () {
      final p = EventProvider();
      p.seedEventsForTest([
        _event(guests: [_guest(id: 'g1', userId: 'u1')]),
      ]);
      p.handleQueueActivityInsert(_activityRow());
      p.handleQueueEntryInsert(_entryRow(userId: 'u1'));
      expect(p.freePoolFor('sess1').any((e) => e.userId == 'u1'), isFalse);

      p.handleQueueActivityDelete(_activityRow());
      // u1 is no longer in any queue → back in free pool
      expect(p.freePoolFor('sess1').any((e) => e.userId == 'u1'), isTrue);
    });
  });

  // ── Entry INSERT ────────────────────────────────────────────────────────────

  group('handleQueueEntryInsert', () {
    test('adds entry to _queueEntries', () {
      final p = EventProvider();
      p.handleQueueActivityInsert(_activityRow());
      p.handleQueueEntryInsert(_entryRow(id: 'e1', userId: 'u1'));

      expect(p.entriesFor('act1').length, 1);
      expect(p.entriesFor('act1').first.id, 'e1');
    });

    test('removes joiner from free pool immediately', () {
      final p = EventProvider();
      p.seedEventsForTest([
        _event(guests: [
          _guest(id: 'g1', userId: 'u1'),
          _guest(id: 'g2', userId: 'u2'),
        ]),
      ]);
      p.handleQueueActivityInsert(_activityRow());

      expect(p.freePoolFor('sess1').length, 2);

      p.handleQueueEntryInsert(_entryRow(userId: 'u1'));

      expect(p.freePoolFor('sess1').length, 1);
      expect(p.freePoolFor('sess1').first.userId, 'u2');
    });

    test('is idempotent — duplicate INSERT does not add duplicate entry', () {
      final p = EventProvider();
      p.handleQueueActivityInsert(_activityRow());
      p.handleQueueEntryInsert(_entryRow(id: 'e1'));
      p.handleQueueEntryInsert(_entryRow(id: 'e1')); // duplicate

      expect(p.entriesFor('act1').length, 1);
    });

    test('works even when entry INSERT arrives before activity INSERT (race)', () {
      final p = EventProvider();
      p.seedEventsForTest([
        _event(guests: [_guest(id: 'g1', userId: 'u1')]),
      ]);
      // Entry INSERT arrives first (race condition)
      p.handleQueueEntryInsert(_entryRow(userId: 'u1'));
      // Activity INSERT arrives later
      p.handleQueueActivityInsert(_activityRow());

      // After activity INSERT recomputes pool, u1 is excluded
      expect(p.freePoolFor('sess1').any((e) => e.userId == 'u1'), isFalse);
    });

    test('multiple users fill spots in order', () {
      final p = EventProvider();
      p.handleQueueActivityInsert(_activityRow(spots: 4));
      p.handleQueueEntryInsert(_entryRow(id: 'e1', userId: 'u1', queuePosition: 1));
      p.handleQueueEntryInsert(_entryRow(id: 'e2', userId: 'u2', queuePosition: 2));

      final entries = p.entriesFor('act1');
      expect(entries.length, 2);
      expect(entries.first.userId, 'u1');
      expect(entries.last.userId, 'u2');
    });
  });

  // ── Entry DELETE ────────────────────────────────────────────────────────────

  group('handleQueueEntryDelete', () {
    test('removes entry and returns user to free pool', () {
      final p = EventProvider();
      p.seedEventsForTest([
        _event(guests: [
          _guest(id: 'g1', userId: 'u1'),
          _guest(id: 'g2', userId: 'u2'),
        ]),
      ]);
      p.handleQueueActivityInsert(_activityRow());
      p.handleQueueEntryInsert(_entryRow(id: 'e1', userId: 'u1'));

      expect(p.freePoolFor('sess1').length, 1); // u2 only

      p.handleQueueEntryDelete(_entryRow(id: 'e1', userId: 'u1'));

      expect(p.freePoolFor('sess1').length, 2); // u1 back
      expect(p.entriesFor('act1'), isEmpty);
    });

    test('delete for unknown entry is a no-op', () {
      final p = EventProvider();
      p.handleQueueActivityInsert(_activityRow());
      p.handleQueueEntryInsert(_entryRow(id: 'e1', userId: 'u1'));

      p.handleQueueEntryDelete(_entryRow(id: 'no-such-id', userId: 'u1'));

      expect(p.entriesFor('act1').length, 1); // original entry still there
    });

    test('clear_queue: all entries deleted → all users back in free pool', () {
      final p = EventProvider();
      p.seedEventsForTest([
        _event(guests: [
          _guest(id: 'g1', userId: 'u1'),
          _guest(id: 'g2', userId: 'u2'),
          _guest(id: 'g3', userId: 'u3'),
        ]),
      ]);
      p.handleQueueActivityInsert(_activityRow(spots: 4));
      p.handleQueueEntryInsert(_entryRow(id: 'e1', userId: 'u1', queuePosition: 1));
      p.handleQueueEntryInsert(_entryRow(id: 'e2', userId: 'u2', queuePosition: 2));

      expect(p.freePoolFor('sess1').length, 1); // u3 only

      // Organizer clears queue → cascade DELETE fires for each entry
      p.handleQueueEntryDelete(_entryRow(id: 'e1', userId: 'u1'));
      p.handleQueueEntryDelete(_entryRow(id: 'e2', userId: 'u2'));

      expect(p.freePoolFor('sess1').length, 3); // all back
      expect(p.entriesFor('act1'), isEmpty);
    });
  });

  // ── Entry UPDATE ────────────────────────────────────────────────────────────

  group('handleQueueEntryUpdate', () {
    test('updates entry in place — leave_queue renumber scenario', () {
      final p = EventProvider();
      p.handleQueueActivityInsert(_activityRow());
      // e1 at #1, e2 at #2, e3 at #3
      p.handleQueueEntryInsert(_entryRow(id: 'e1', userId: 'u1', queuePosition: 1));
      p.handleQueueEntryInsert(_entryRow(id: 'e2', userId: 'u2', queuePosition: 2));
      p.handleQueueEntryInsert(_entryRow(id: 'e3', userId: 'u3', queuePosition: 3));

      // e1 leaves → DELETE (e2→#1, e3→#2 via UPDATE)
      p.handleQueueEntryDelete(_entryRow(id: 'e1', userId: 'u1', queuePosition: 1));
      p.handleQueueEntryUpdate(_entryRow(id: 'e2', userId: 'u2', queuePosition: 1));
      p.handleQueueEntryUpdate(_entryRow(id: 'e3', userId: 'u3', queuePosition: 2));

      final entries = p.entriesFor('act1');
      expect(entries.length, 2);
      expect(entries[0].id, 'e2');
      expect(entries[0].queuePosition, 1);
      expect(entries[1].id, 'e3');
      expect(entries[1].queuePosition, 2);
    });

    test('UPDATE for unknown activityId is a no-op', () {
      final p = EventProvider();
      expect(
        () => p.handleQueueEntryUpdate(_entryRow(activityId: 'ghost')),
        returnsNormally,
      );
    });
  });

  // ── _recomputeFreePool business logic ───────────────────────────────────────

  group('_recomputeFreePool / freePoolFor', () {
    test('excludes declined and left guests', () {
      final p = EventProvider();
      p.seedEventsForTest([
        _event(guests: [
          _guest(id: 'g1', userId: 'u1', status: 'going'),
          _guest(id: 'g2', userId: 'u2', status: 'declined'),
          _guest(id: 'g3', userId: 'u3', status: 'left'),
          _guest(id: 'g4', userId: 'u4', status: 'maybe'),
        ]),
      ]);
      p.handleQueueActivityInsert(_activityRow());

      final pool = p.freePoolFor('sess1');
      expect(pool.map((e) => e.userId).toSet(), {'u1', 'u4'});
    });

    test('includes anonymous guests (null userId) using guest.id as placeholder', () {
      final p = EventProvider();
      p.seedEventsForTest([
        _event(guests: [
          _guest(id: 'g1', userId: 'u1'),
          EventGuest(
            id: 'g-anon',
            eventId: 'ev1',
            userId: null, // anonymous
            displayName: 'Walk-in',
            status: 'going',
            rsvpAt: DateTime(2026, 6, 1),
            createdAt: DateTime(2026, 6, 1),
          ),
        ]),
      ]);
      p.handleQueueActivityInsert(_activityRow());

      final pool = p.freePoolFor('sess1');
      expect(pool.length, 2);
      // Anonymous guest uses guest.id as userId placeholder
      expect(pool.any((e) => e.userId == 'g-anon'), isTrue);
    });

    test('anonymous guests always stay in pool (cannot join queues)', () {
      final p = EventProvider();
      p.seedEventsForTest([
        _event(guests: [
          EventGuest(
            id: 'g-anon',
            eventId: 'ev1',
            userId: null,
            displayName: 'Walk-in',
            status: 'going',
            rsvpAt: DateTime(2026, 6, 1),
            createdAt: DateTime(2026, 6, 1),
          ),
        ]),
      ]);
      p.handleQueueActivityInsert(_activityRow());
      // Simulate an authenticated user joining (not the anonymous one)
      p.handleQueueEntryInsert(_entryRow(userId: 'other-user'));

      // Anonymous guest is unaffected — still in pool
      expect(p.freePoolFor('sess1').any((e) => e.userId == 'g-anon'), isTrue);
    });

    test('freePoolFor returns empty for unknown sessionId', () {
      final p = EventProvider();
      expect(p.freePoolFor('no-such-session'), isEmpty);
    });

    test('multi-queue: user in queue2 is excluded from pool', () {
      final p = EventProvider();
      p.seedEventsForTest([
        _event(guests: [
          _guest(id: 'g1', userId: 'u1'),
          _guest(id: 'g2', userId: 'u2'),
        ]),
      ]);
      p.handleQueueActivityInsert(_activityRow(id: 'act1', sortOrder: 1));
      p.handleQueueActivityInsert(
          _activityRow(id: 'act2', sortOrder: 2));
      // u2 joins queue 2
      p.handleQueueEntryInsert(
          _entryRow(id: 'e1', activityId: 'act2', userId: 'u2'));

      final pool = p.freePoolFor('sess1');
      expect(pool.length, 1);
      expect(pool.first.userId, 'u1');
    });

    test('setup_session_queues: delete all then insert new → pool resets', () {
      final p = EventProvider();
      p.seedEventsForTest([
        _event(guests: [_guest(id: 'g1', userId: 'u1')]),
      ]);
      p.handleQueueActivityInsert(_activityRow(id: 'act-old'));
      p.handleQueueEntryInsert(_entryRow(activityId: 'act-old', userId: 'u1'));
      expect(p.freePoolFor('sess1').any((e) => e.userId == 'u1'), isFalse);

      // Organizer replaces queues
      p.handleQueueEntryDelete(_entryRow(activityId: 'act-old', userId: 'u1'));
      p.handleQueueActivityDelete(_activityRow(id: 'act-old'));
      p.handleQueueActivityInsert(_activityRow(id: 'act-new'));

      expect(p.freePoolFor('sess1').any((e) => e.userId == 'u1'), isTrue);
      expect(p.queuesFor('sess1').first.id, 'act-new');
    });
  });

  // ── queuesFor / entriesFor safe defaults ─────────────────────────────────────

  group('queue accessor safe defaults', () {
    test('queuesFor returns empty for unknown sessionId', () {
      expect(EventProvider().queuesFor('x'), isEmpty);
    });

    test('entriesFor returns empty for unknown activityId', () {
      expect(EventProvider().entriesFor('x'), isEmpty);
    });
  });

  // ── allow_duplicates propagation ─────────────────────────────────────────────

  group('allow_duplicates', () {
    test('defaults to false when field is absent from row', () {
      final row = _activityRow()..remove('allow_duplicates');
      final p = EventProvider();
      p.handleQueueActivityInsert(row);
      expect(p.queuesFor('sess1').first.allowDuplicates, isFalse);
    });

    test('is true when row sets allow_duplicates = true', () {
      final p = EventProvider();
      p.handleQueueActivityInsert(_activityRow(allowDuplicates: true));
      expect(p.queuesFor('sess1').first.allowDuplicates, isTrue);
    });

    test('is preserved through copyWith', () {
      final p = EventProvider();
      p.handleQueueActivityInsert(_activityRow(allowDuplicates: true));
      final updated = p.queuesFor('sess1').first.copyWith(sortOrder: 99);
      expect(updated.allowDuplicates, isTrue);
    });

    test('update row can flip allow_duplicates', () {
      final p = EventProvider();
      p.handleQueueActivityInsert(_activityRow(allowDuplicates: false));
      p.handleQueueActivityUpdate(_activityRow(allowDuplicates: true));
      expect(p.queuesFor('sess1').first.allowDuplicates, isTrue);
    });
  });
}
