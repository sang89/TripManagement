import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/event_session.dart';

void main() {
  // ── EventSession ─────────────────────────────────────────────────────────────

  // Use a clearly past start/end so hasEnded and isUpcoming base-fixture tests
  // don't require time-sensitive overrides.
  final baseJson = {
    'id': 's1',
    'event_id': 'e1',
    'session_number': 3,
    'start_at': '2024-01-01T18:00:00.000Z',
    'end_at': '2024-01-01T20:00:00.000Z',
    'invite_code': 'abc-invite',
    'created_at': '2024-01-01T08:00:00.000Z',
    'going_count': 5,
    'waitlist_count': 2,
    'capacity': 10,
    'waitlist_enabled': true,
    'signup_lock_hours': 2,
    'is_public': true,
    'requires_approval': false,
  };

  group('EventSession.fromJson', () {
    test('parses all fields', () {
      final s = EventSession.fromJson(baseJson);
      expect(s.id, 's1');
      expect(s.eventId, 'e1');
      expect(s.sessionNumber, 3);
      expect(s.startAt, DateTime.utc(2024, 1, 1, 18));
      expect(s.endAt, DateTime.utc(2024, 1, 1, 20));
      expect(s.inviteCode, 'abc-invite');
      expect(s.goingCount, 5);
      expect(s.waitlistCount, 2);
      expect(s.capacity, 10);
      expect(s.waitlistEnabled, isTrue);
      expect(s.signupLockHours, 2);
      expect(s.isPublic, isTrue);
      expect(s.requiresApproval, isFalse);
    });

    test('handles optional fields absent with safe defaults', () {
      final j = {
        'id': 's2',
        'event_id': 'e1',
        'session_number': 1,
        'start_at': '2026-07-04T18:00:00.000Z',
        'invite_code': 'xyz',
        'created_at': '2026-06-01T08:00:00.000Z',
      };
      final s = EventSession.fromJson(j);
      expect(s.endAt, isNull);
      expect(s.goingCount, 0);
      expect(s.waitlistCount, 0);
      expect(s.capacity, isNull);
      expect(s.waitlistEnabled, isTrue);
      expect(s.signupLockHours, isNull);
      expect(s.isPublic, isTrue);
      expect(s.requiresApproval, isFalse);
    });

    test('parses requiresApproval=true', () {
      final j = Map<String, dynamic>.from(baseJson)
        ..['requires_approval'] = true;
      final s = EventSession.fromJson(j);
      expect(s.requiresApproval, isTrue);
    });

    test('parses isPublic=false', () {
      final j = Map<String, dynamic>.from(baseJson)..['is_public'] = false;
      final s = EventSession.fromJson(j);
      expect(s.isPublic, isFalse);
    });
  });

  group('EventSession.isFull', () {
    test('false when capacity is null', () {
      final j = Map<String, dynamic>.from(baseJson)..remove('capacity');
      expect(EventSession.fromJson(j).isFull, isFalse);
    });

    test('false when going < capacity', () {
      final j = Map<String, dynamic>.from(baseJson)
        ..['going_count'] = 4
        ..['capacity'] = 10;
      expect(EventSession.fromJson(j).isFull, isFalse);
    });

    test('true when going == capacity', () {
      final j = Map<String, dynamic>.from(baseJson)
        ..['going_count'] = 10
        ..['capacity'] = 10;
      expect(EventSession.fromJson(j).isFull, isTrue);
    });

    test('true when going > capacity', () {
      final j = Map<String, dynamic>.from(baseJson)
        ..['going_count'] = 12
        ..['capacity'] = 10;
      expect(EventSession.fromJson(j).isFull, isTrue);
    });
  });

  group('EventSession.isLocked', () {
    test('false when signupLockHours is null', () {
      final j = Map<String, dynamic>.from(baseJson)
        ..remove('signup_lock_hours');
      expect(EventSession.fromJson(j).isLocked, isFalse);
    });

    test('false when session starts far in the future (outside lock window)', () {
      // Lock = 2 hours, session starts 5 hours from now → not yet locked.
      final startAt =
          DateTime.now().toUtc().add(const Duration(hours: 5)).toIso8601String();
      final j = Map<String, dynamic>.from(baseJson)
        ..['start_at'] = startAt
        ..['signup_lock_hours'] = 2;
      expect(EventSession.fromJson(j).isLocked, isFalse);
    });

    test('true when now is inside the lock window', () {
      // Lock = 2 hours, session starts 1 hour from now → locked.
      final startAt = DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .toIso8601String();
      final j = Map<String, dynamic>.from(baseJson)
        ..['start_at'] = startAt
        ..['signup_lock_hours'] = 2;
      expect(EventSession.fromJson(j).isLocked, isTrue);
    });

    test('true when session has already started', () {
      // Session started 10 minutes ago → always locked.
      final startAt = DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 10))
          .toIso8601String();
      final j = Map<String, dynamic>.from(baseJson)
        ..['start_at'] = startAt
        ..['signup_lock_hours'] = 2;
      expect(EventSession.fromJson(j).isLocked, isTrue);
    });
  });

  group('EventSession.hasEnded', () {
    test('true when now is after endAt', () {
      final s = EventSession.fromJson(baseJson); // endAt = 2026-07-04 past
      expect(s.hasEnded, isTrue);
    });

    test('false when endAt is in the future', () {
      final endAt = DateTime.now()
          .toUtc()
          .add(const Duration(hours: 2))
          .toIso8601String();
      final j = Map<String, dynamic>.from(baseJson)..['end_at'] = endAt;
      expect(EventSession.fromJson(j).hasEnded, isFalse);
    });

    test('true when endAt is null and startAt is in the past', () {
      final j = Map<String, dynamic>.from(baseJson)
        ..remove('end_at')
        ..['start_at'] =
            DateTime.now().toUtc().subtract(const Duration(hours: 1)).toIso8601String();
      expect(EventSession.fromJson(j).hasEnded, isTrue);
    });

    test('false when endAt is null and startAt is in the future', () {
      final j = Map<String, dynamic>.from(baseJson)
        ..remove('end_at')
        ..['start_at'] =
            DateTime.now().toUtc().add(const Duration(hours: 2)).toIso8601String();
      expect(EventSession.fromJson(j).hasEnded, isFalse);
    });
  });

  group('EventSession.isUpcoming', () {
    test('true when startAt is in the future', () {
      final j = Map<String, dynamic>.from(baseJson)
        ..['start_at'] =
            DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String();
      expect(EventSession.fromJson(j).isUpcoming, isTrue);
    });

    test('false when startAt is in the past', () {
      expect(EventSession.fromJson(baseJson).isUpcoming, isFalse);
    });
  });

  group('EventSession.copyWithCounts', () {
    test('updates going and waitlist counts independently', () {
      final s = EventSession.fromJson(baseJson);
      final updated = s.copyWithCounts(goingCount: 8);
      expect(updated.goingCount, 8);
      expect(updated.waitlistCount, s.waitlistCount); // unchanged

      final updated2 = s.copyWithCounts(waitlistCount: 0);
      expect(updated2.waitlistCount, 0);
      expect(updated2.goingCount, s.goingCount); // unchanged
    });

    test('preserves all other fields', () {
      final s = EventSession.fromJson(baseJson);
      final updated = s.copyWithCounts(goingCount: 1, waitlistCount: 0);
      expect(updated.id, s.id);
      expect(updated.eventId, s.eventId);
      expect(updated.sessionNumber, s.sessionNumber);
      expect(updated.capacity, s.capacity);
      expect(updated.waitlistEnabled, s.waitlistEnabled);
      expect(updated.signupLockHours, s.signupLockHours);
      expect(updated.isPublic, s.isPublic);
      expect(updated.requiresApproval, s.requiresApproval);
    });
  });

  // ── EventSessionRosterEntry ──────────────────────────────────────────────────

  final baseRosterJson = {
    'id': 'r1',
    'session_id': 's1',
    'user_id': 'u1',
    'display_name': 'Alice',
    'email': 'alice@example.com',
    'phone': '+1234567890',
    'status': 'going',
    'signup_order': 2,
    'attended': null,
    'signup_confirmed': false,
    'signed_up_at': '2026-06-15T10:00:00.000Z',
  };

  group('EventSessionRosterEntry.fromJson', () {
    test('parses all fields', () {
      final r = EventSessionRosterEntry.fromJson(baseRosterJson);
      expect(r.id, 'r1');
      expect(r.sessionId, 's1');
      expect(r.userId, 'u1');
      expect(r.displayName, 'Alice');
      expect(r.email, 'alice@example.com');
      expect(r.phone, '+1234567890');
      expect(r.status, 'going');
      expect(r.signupOrder, 2);
      expect(r.attended, isNull);
      expect(r.signupConfirmed, isFalse);
      expect(r.signedUpAt, DateTime.utc(2026, 6, 15, 10));
    });

    test('handles optional fields absent with safe defaults', () {
      final j = {
        'id': 'r2',
        'session_id': 's1',
        'display_name': 'Bob',
        'signed_up_at': '2026-06-15T10:00:00.000Z',
      };
      final r = EventSessionRosterEntry.fromJson(j);
      expect(r.userId, isNull);
      expect(r.email, isNull);
      expect(r.phone, isNull);
      expect(r.status, 'going');
      expect(r.signupOrder, isNull);
      expect(r.attended, isNull);
      expect(r.signupConfirmed, isFalse);
    });

    test('defaults status to "going" when missing', () {
      final j = Map<String, dynamic>.from(baseRosterJson)..remove('status');
      expect(EventSessionRosterEntry.fromJson(j).status, 'going');
    });

    test('parses waitlisted status', () {
      final j = Map<String, dynamic>.from(baseRosterJson)
        ..['status'] = 'waitlisted';
      expect(EventSessionRosterEntry.fromJson(j).status, 'waitlisted');
    });

    test('parses pending_review status', () {
      final j = Map<String, dynamic>.from(baseRosterJson)
        ..['status'] = 'pending_review';
      expect(EventSessionRosterEntry.fromJson(j).status, 'pending_review');
    });

    test('parses attended=true and attended=false', () {
      final attended = Map<String, dynamic>.from(baseRosterJson)
        ..['attended'] = true;
      expect(EventSessionRosterEntry.fromJson(attended).attended, isTrue);

      final noShow = Map<String, dynamic>.from(baseRosterJson)
        ..['attended'] = false;
      expect(EventSessionRosterEntry.fromJson(noShow).attended, isFalse);
    });

    test('parses signup_confirmed=true', () {
      final j = Map<String, dynamic>.from(baseRosterJson)
        ..['signup_confirmed'] = true;
      expect(EventSessionRosterEntry.fromJson(j).signupConfirmed, isTrue);
    });
  });

  group('EventSessionRosterEntry computed properties', () {
    test('isGoing true only for going status', () {
      final going = EventSessionRosterEntry.fromJson(baseRosterJson);
      expect(going.isGoing, isTrue);
      expect(going.isWaitlisted, isFalse);
    });

    test('isWaitlisted true only for waitlisted status', () {
      final j = Map<String, dynamic>.from(baseRosterJson)
        ..['status'] = 'waitlisted';
      final waitlisted = EventSessionRosterEntry.fromJson(j);
      expect(waitlisted.isWaitlisted, isTrue);
      expect(waitlisted.isGoing, isFalse);
    });

    test('neither isGoing nor isWaitlisted for pending_review', () {
      final j = Map<String, dynamic>.from(baseRosterJson)
        ..['status'] = 'pending_review';
      final pending = EventSessionRosterEntry.fromJson(j);
      expect(pending.isGoing, isFalse);
      expect(pending.isWaitlisted, isFalse);
    });
  });

  group('EventSessionRosterEntry.copyWith', () {
    test('updates status', () {
      final r = EventSessionRosterEntry.fromJson(baseRosterJson);
      final promoted = r.copyWith(status: 'waitlisted');
      expect(promoted.status, 'waitlisted');
      expect(promoted.id, r.id);
    });

    test('updates attended', () {
      final r = EventSessionRosterEntry.fromJson(baseRosterJson);
      final marked = r.copyWith(attended: true);
      expect(marked.attended, isTrue);
      expect(marked.status, r.status);
    });

    test('updates signupConfirmed', () {
      final r = EventSessionRosterEntry.fromJson(baseRosterJson);
      final confirmed = r.copyWith(signupConfirmed: true);
      expect(confirmed.signupConfirmed, isTrue);
    });

    test('updates signupOrder', () {
      final r = EventSessionRosterEntry.fromJson(baseRosterJson);
      final reordered = r.copyWith(signupOrder: 5);
      expect(reordered.signupOrder, 5);
      expect(reordered.displayName, r.displayName);
    });

    test('preserves unchanged fields when only one field is updated', () {
      final r = EventSessionRosterEntry.fromJson(baseRosterJson);
      final updated = r.copyWith(status: 'waitlisted');
      expect(updated.userId, r.userId);
      expect(updated.displayName, r.displayName);
      expect(updated.email, r.email);
      expect(updated.phone, r.phone);
      expect(updated.signupOrder, r.signupOrder);
      expect(updated.signedUpAt, r.signedUpAt);
    });
  });
}
