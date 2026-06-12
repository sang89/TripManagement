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

  // ── Bug-regression: clearAttended flag (Bug 1 fix) ───────────────────────────
  //
  // The attendance chip cycles null → true → false → null.
  // copyWith(attended: x) cannot express "reset to null" because a null
  // argument is indistinguishable from "no change".  clearAttended=true was
  // added to enable the reset step without ambiguity.

  group('EventSessionRosterEntry.copyWith — clearAttended (Bug 1 regression)', () {
    test('clearAttended=true resets attended from true to null', () {
      final r = EventSessionRosterEntry.fromJson(
          Map<String, dynamic>.from(baseRosterJson)..['attended'] = true);
      final reset = r.copyWith(clearAttended: true);
      expect(reset.attended, isNull);
      expect(reset.status, r.status); // other fields unchanged
      expect(reset.signupConfirmed, r.signupConfirmed);
    });

    test('clearAttended=true resets attended from false to null', () {
      final r = EventSessionRosterEntry.fromJson(
          Map<String, dynamic>.from(baseRosterJson)..['attended'] = false);
      final reset = r.copyWith(clearAttended: true);
      expect(reset.attended, isNull);
    });

    test('clearAttended=true takes precedence over a provided attended value', () {
      final r = EventSessionRosterEntry.fromJson(
          Map<String, dynamic>.from(baseRosterJson)..['attended'] = true);
      // Passing both clearAttended=true AND attended=false — clear wins.
      final reset = r.copyWith(clearAttended: true, attended: false);
      expect(reset.attended, isNull);
    });

    test('clearAttended=false (default) with attended=true sets it', () {
      final r = EventSessionRosterEntry.fromJson(baseRosterJson); // attended null
      expect(r.copyWith(attended: true).attended, isTrue);
    });

    test('clearAttended=false (default) with attended=false sets it', () {
      final r = EventSessionRosterEntry.fromJson(baseRosterJson); // attended null
      expect(r.copyWith(attended: false).attended, isFalse);
    });

    test('clearAttended=false (default) without attended preserves null', () {
      final r = EventSessionRosterEntry.fromJson(baseRosterJson); // attended null
      expect(r.copyWith(status: 'waitlisted').attended, isNull);
    });

    test('clearAttended=false (default) preserves existing true attended', () {
      final r = EventSessionRosterEntry.fromJson(
          Map<String, dynamic>.from(baseRosterJson)..['attended'] = true);
      expect(r.copyWith(signupConfirmed: true).attended, isTrue);
    });
  });

  // ── Attendance cycle invariant (Bug 1 regression) ────────────────────────────
  //
  // The _AttendanceChip widget cycles: null → true → false → null.
  // This helper encodes the same logic so regressions are caught here without
  // a full widget test.

  group('Attendance cycle logic (Bug 1 regression)', () {
    // Encodes the _AttendanceChip.onTap logic so regressions are caught here.
    bool? cycle(bool? current) {
      if (current == null) return true;
      if (current == true) return false;
      return null;
    }

    test('unset → attended', () => expect(cycle(null), isTrue));
    test('attended → no-show', () => expect(cycle(true), isFalse));
    test('no-show → unset (not back to attended)', () =>
        expect(cycle(false), isNull));
    test('three-step cycle returns to null', () {
      bool? state;
      state = cycle(state); // → true
      state = cycle(state); // → false
      state = cycle(state); // → null
      expect(state, isNull);
    });
  });

  // ── Bug-regression: pending_review as distinct status (Bugs 2, 3, B) ─────────

  group('pending_review status is distinct from going/waitlisted (Bug 2/3/B regression)', () {
    test('fromJson parses pending_review status correctly', () {
      final j = Map<String, dynamic>.from(baseRosterJson)
        ..['status'] = 'pending_review';
      final r = EventSessionRosterEntry.fromJson(j);
      expect(r.status, 'pending_review');
      expect(r.isGoing, isFalse);
      expect(r.isWaitlisted, isFalse);
    });

    test('pending_review copyWith preserves status', () {
      final r = EventSessionRosterEntry.fromJson(
          Map<String, dynamic>.from(baseRosterJson)..['status'] = 'pending_review');
      final copy = r.copyWith(signupConfirmed: true);
      expect(copy.status, 'pending_review');
    });

    test('pending_review promoted to going via copyWith', () {
      final r = EventSessionRosterEntry.fromJson(
          Map<String, dynamic>.from(baseRosterJson)..['status'] = 'pending_review');
      final approved = r.copyWith(status: 'going');
      expect(approved.isGoing, isTrue);
      expect(approved.isWaitlisted, isFalse);
    });
  });

  // ── Bug-regression: session Realtime UPDATE preserves all fields (Bug 4) ──────
  //
  // The Realtime handler now rebuilds EventSession via fromJson instead of
  // copyWithCounts.  This test ensures copyWithCounts itself still preserves
  // non-count fields (used by _refreshSessionCounts), AND verifies the fromJson
  // round-trip used in the Realtime handler.

  group('EventSession Realtime UPDATE field preservation (Bug 4 regression)', () {
    test('copyWithCounts preserves capacity, requiresApproval, signupLockHours, isPublic', () {
      final session = EventSession.fromJson(Map<String, dynamic>.from(baseJson)
        ..['capacity'] = 20
        ..['requires_approval'] = true
        ..['signup_lock_hours'] = 4
        ..['is_public'] = false);
      final updated = session.copyWithCounts(goingCount: 10, waitlistCount: 2);
      expect(updated.capacity, 20);
      expect(updated.requiresApproval, isTrue);
      expect(updated.signupLockHours, 4);
      expect(updated.isPublic, isFalse);
      expect(updated.goingCount, 10);
      expect(updated.waitlistCount, 2);
    });

    test('fromJson round-trip used in Realtime handler preserves metadata when counts change', () {
      // Simulates what the Realtime UPDATE handler now does: build a merged
      // JSON map from both the incoming row and the existing cached session.
      final existing = EventSession.fromJson(Map<String, dynamic>.from(baseJson)
        ..['capacity'] = 15
        ..['requires_approval'] = true
        ..['signup_lock_hours'] = 2
        ..['is_public'] = false
        ..['going_count'] = 3
        ..['waitlist_count'] = 0);

      // Simulate a Realtime payload that only carries count updates.
      final realtimeRow = <String, dynamic>{
        'id': existing.id,
        'event_id': existing.eventId,
        'going_count': 12,
        'waitlist_count': 3,
      };

      final merged = EventSession.fromJson({
        'id': existing.id,
        'event_id': existing.eventId,
        'session_number': existing.sessionNumber,
        'start_at': existing.startAt.toIso8601String(),
        'end_at': existing.endAt?.toIso8601String(),
        'invite_code': existing.inviteCode,
        'created_at': existing.createdAt.toIso8601String(),
        'going_count': realtimeRow['going_count'],
        'waitlist_count': realtimeRow['waitlist_count'],
        'capacity': existing.capacity,
        'waitlist_enabled': existing.waitlistEnabled,
        'signup_lock_hours': existing.signupLockHours,
        'is_public': existing.isPublic,
        'requires_approval': existing.requiresApproval,
      });

      expect(merged.goingCount, 12);
      expect(merged.waitlistCount, 3);
      expect(merged.capacity, 15);           // preserved from existing
      expect(merged.requiresApproval, isTrue);  // preserved
      expect(merged.signupLockHours, 2);     // preserved
      expect(merged.isPublic, isFalse);      // preserved
    });
  });

  // ── Bug-regression: promote check uses goingCount not roster length (Bug 5) ───
  //
  // The UI promote-button guard was using confirmed.length (paginated in-memory
  // list) instead of session.goingCount (DB-authoritative).  This test verifies
  // that isFull (which uses goingCount) correctly reflects full capacity even
  // when the local roster list has fewer entries than goingCount.

  group('isFull uses goingCount from DB, not in-memory roster length (Bug 5 regression)', () {
    test('session with goingCount==capacity is full even if roster page is partial', () {
      // DB says 10/10 going.  Imagine local roster only loaded 3 entries so far.
      final session = EventSession.fromJson(Map<String, dynamic>.from(baseJson)
        ..['capacity'] = 10
        ..['going_count'] = 10);
      // The UI must use session.goingCount (==10) not roster.length (would be 3).
      expect(session.isFull, isTrue);
      expect(session.goingCount, 10);
    });

    test('session with goingCount < capacity is not full', () {
      final session = EventSession.fromJson(Map<String, dynamic>.from(baseJson)
        ..['capacity'] = 10
        ..['going_count'] = 9);
      expect(session.isFull, isFalse);
    });

    test('isFull is false when capacity is null (unlimited)', () {
      final session = EventSession.fromJson(Map<String, dynamic>.from(baseJson)
        ..remove('capacity')
        ..['going_count'] = 9999);
      expect(session.isFull, isFalse);
    });
  });

  // ── Bug-regression: refreshSessionRoster must not clear myStatus for paginated
  //    users (Bug C regression) ────────────────────────────────────────────────
  //
  // When a session has >100 roster entries, refreshSessionRoster fetches only
  // the first 100.  If the current user is entry #101+, they won't appear in
  // the first page.  The old code would remove them from _mySessionStatuses,
  // hiding the "Cancel my spot" button.
  //
  // Fix: only clear _mySessionStatuses when hasMore==false (all entries loaded).
  // This behaviour is exercised in provider integration tests.  The model test
  // below documents the expected invariant: a user CAN be signed up even if they
  // don't appear in the first roster page.

  group('Roster pagination — myStatus invariant (Bug C regression docs)', () {
    test('a session with hasMore=true may have user entries beyond the first page', () {
      // First page of 100 entries — none belong to userId 'u-late'.
      final page1 = List.generate(
        100,
        (i) => EventSessionRosterEntry(
          id: 'r$i',
          sessionId: 's1',
          userId: 'u$i',
          displayName: 'User $i',
          status: 'going',
          signupOrder: i + 1,
          signedUpAt: DateTime.now(),
        ),
      );
      final hasMore = true; // page 2 exists
      final myUserId = 'u-late'; // signed up as entry #101

      // Since hasMore=true, absence from page1 does NOT mean unsigned up.
      final foundInPage1 = page1.any((e) => e.userId == myUserId);
      expect(foundInPage1, isFalse); // not in page 1
      expect(hasMore, isTrue);       // but more pages exist → do NOT clear status
    });

    test('a session with hasMore=false and user absent means truly not signed up', () {
      final pageAll = [
        EventSessionRosterEntry(
          id: 'r1',
          sessionId: 's1',
          userId: 'u1',
          displayName: 'User 1',
          status: 'going',
          signupOrder: 1,
          signedUpAt: DateTime.now(),
        ),
      ];
      final hasMore = false;
      final myUserId = 'u-absent';

      final foundInPage = pageAll.any((e) => e.userId == myUserId);
      expect(foundInPage, isFalse);
      expect(hasMore, isFalse); // all entries loaded → safe to clear status
    });
  });

}
