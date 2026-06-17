import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/session_queue.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _activityJson({
  String id = 'act1',
  String sessionId = 'sess1',
  String eventId = 'ev1',
  int spots = 4,
  int sortOrder = 1,
  String status = 'active',
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
      'status': status,
      'waiting_count': 0,
      'playing_count': 0,
      'sort_order': sortOrder,
      'allow_duplicates': allowDuplicates,
      'created_by': 'organizer',
      'created_at': '2026-06-16T00:00:00Z',
    };

Map<String, dynamic> _entryJson({
  String id = 'entry1',
  String activityId = 'act1',
  String? userId = 'user1',
  String displayName = 'Alice',
  String? avatarUrl,
  String status = 'playing',
  int queuePosition = 1,
  int roundsPlayed = 0,
}) =>
    {
      'id': id,
      'activity_id': activityId,
      'user_id': userId,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'status': status,
      'queue_position': queuePosition,
      'rounds_played': roundsPlayed,
      'joined_at': '2026-06-16T00:00:00Z',
    };

Map<String, dynamic> _freePoolJson({
  String id = 'fp1',
  String eventId = 'ev1',
  String sessionId = 'sess1',
  String userId = 'user1',
  String displayName = 'Bob',
  String? avatarUrl,
}) =>
    {
      'id': id,
      'event_id': eventId,
      'session_id': sessionId,
      'user_id': userId,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'checked_in_at': '2026-06-16T00:00:00Z',
    };

// ─── SessionQueueActivity ─────────────────────────────────────────────────────

void main() {
  group('SessionQueueActivity.fromJson', () {
    test('parses all fields correctly', () {
      final a = SessionQueueActivity.fromJson(_activityJson(
        id: 'act1',
        sessionId: 'sess1',
        spots: 4,
        sortOrder: 2,
        status: 'active',
        allowDuplicates: true,
      ));

      expect(a.id, 'act1');
      expect(a.sessionId, 'sess1');
      expect(a.playersPerRound, 4);
      expect(a.sortOrder, 2);
      expect(a.status, QueueStatus.active);
      expect(a.allowDuplicates, isTrue);
    });

    test('allow_duplicates defaults to false when absent', () {
      final json = _activityJson()..remove('allow_duplicates');
      final a = SessionQueueActivity.fromJson(json);
      expect(a.allowDuplicates, isFalse);
    });

    test('parses status variants', () {
      expect(
        SessionQueueActivity.fromJson(_activityJson(status: 'waiting')).status,
        QueueStatus.waiting,
      );
      expect(
        SessionQueueActivity.fromJson(_activityJson(status: 'ended')).status,
        QueueStatus.ended,
      );
      expect(
        SessionQueueActivity.fromJson(_activityJson(status: 'unknown')).status,
        QueueStatus.waiting, // fallback
      );
    });

    test('status helpers are consistent', () {
      final active = SessionQueueActivity.fromJson(_activityJson(status: 'active'));
      expect(active.isActive, isTrue);
      expect(active.isWaiting, isFalse);
      expect(active.isEnded, isFalse);

      final waiting = SessionQueueActivity.fromJson(_activityJson(status: 'waiting'));
      expect(waiting.isWaiting, isTrue);

      final ended = SessionQueueActivity.fromJson(_activityJson(status: 'ended'));
      expect(ended.isEnded, isTrue);
    });
  });

  group('SessionQueueActivity.copyWith', () {
    test('updates specified fields and preserves others', () {
      final original = SessionQueueActivity.fromJson(
          _activityJson(sortOrder: 1, allowDuplicates: true));
      final copy = original.copyWith(sortOrder: 5);

      expect(copy.sortOrder, 5);
      expect(copy.allowDuplicates, isTrue); // preserved
      expect(copy.id, original.id);
      expect(copy.sessionId, original.sessionId);
    });

    test('copyWith with no args returns same values', () {
      final a = SessionQueueActivity.fromJson(_activityJson(allowDuplicates: false));
      final copy = a.copyWith();
      expect(copy.allowDuplicates, isFalse);
      expect(copy.playersPerRound, a.playersPerRound);
    });
  });

  // ─── SessionQueueEntry ──────────────────────────────────────────────────────

  group('SessionQueueEntry.fromJson', () {
    test('parses all fields', () {
      final e = SessionQueueEntry.fromJson(_entryJson(
        id: 'e1',
        activityId: 'act1',
        userId: 'u1',
        displayName: 'Alice',
        status: 'playing',
        queuePosition: 2,
        roundsPlayed: 1,
      ));

      expect(e.id, 'e1');
      expect(e.activityId, 'act1');
      expect(e.userId, 'u1');
      expect(e.displayName, 'Alice');
      expect(e.status, QueueEntryStatus.playing);
      expect(e.queuePosition, 2);
      expect(e.roundsPlayed, 1);
      expect(e.isPlaying, isTrue);
      expect(e.isWaiting, isFalse);
    });

    test('userId can be null (anonymous / non-app guest)', () {
      final e = SessionQueueEntry.fromJson(_entryJson(userId: null));
      expect(e.userId, isNull);
    });

    test('avatarUrl can be null', () {
      final e = SessionQueueEntry.fromJson(_entryJson(avatarUrl: null));
      expect(e.avatarUrl, isNull);
    });

    test('waiting status parses correctly', () {
      final e = SessionQueueEntry.fromJson(_entryJson(status: 'waiting'));
      expect(e.status, QueueEntryStatus.waiting);
      expect(e.isWaiting, isTrue);
      expect(e.isPlaying, isFalse);
    });

    test('unknown status falls back to waiting', () {
      final e = SessionQueueEntry.fromJson(_entryJson(status: 'garbage'));
      expect(e.status, QueueEntryStatus.waiting);
    });

    test('missing joined_at uses DateTime.now() without throwing', () {
      final json = _entryJson()..remove('joined_at');
      expect(() => SessionQueueEntry.fromJson(json), returnsNormally);
    });
  });

  group('SessionQueueEntry.copyWith', () {
    test('updates status and queuePosition, preserves other fields', () {
      final e = SessionQueueEntry.fromJson(_entryJson(
          status: 'waiting', queuePosition: 3, displayName: 'Bob'));
      final updated = e.copyWith(
          status: QueueEntryStatus.playing, queuePosition: 1);

      expect(updated.status, QueueEntryStatus.playing);
      expect(updated.queuePosition, 1);
      expect(updated.displayName, 'Bob'); // preserved
      expect(updated.userId, e.userId);
    });
  });

  // ─── SessionFreePoolEntry ───────────────────────────────────────────────────

  group('SessionFreePoolEntry.fromJson', () {
    test('parses all fields', () {
      final f = SessionFreePoolEntry.fromJson(_freePoolJson(
        id: 'fp1',
        eventId: 'ev1',
        sessionId: 'sess1',
        userId: 'u1',
        displayName: 'Carol',
      ));

      expect(f.id, 'fp1');
      expect(f.eventId, 'ev1');
      expect(f.sessionId, 'sess1');
      expect(f.userId, 'u1');
      expect(f.displayName, 'Carol');
      expect(f.avatarUrl, isNull);
    });

    test('avatarUrl is parsed when present', () {
      final f = SessionFreePoolEntry.fromJson(
          _freePoolJson(avatarUrl: 'https://example.com/avatar.jpg'));
      expect(f.avatarUrl, 'https://example.com/avatar.jpg');
    });

    test('missing checked_in_at uses DateTime.now() without throwing', () {
      final json = _freePoolJson()..remove('checked_in_at');
      expect(() => SessionFreePoolEntry.fromJson(json), returnsNormally);
    });
  });

  // ─── QueueStatus helpers ────────────────────────────────────────────────────

  group('QueueStatus', () {
    test('fromString covers all variants', () {
      expect(QueueStatus.fromString('active'), QueueStatus.active);
      expect(QueueStatus.fromString('ended'), QueueStatus.ended);
      expect(QueueStatus.fromString('waiting'), QueueStatus.waiting);
      expect(QueueStatus.fromString('other'), QueueStatus.waiting);
    });

    test('dbValue round-trips', () {
      for (final s in QueueStatus.values) {
        expect(QueueStatus.fromString(s.dbValue), s);
      }
    });
  });
}
