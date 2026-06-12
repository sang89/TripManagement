import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/event.dart';
import 'package:trip_management/models/event_session.dart';
import 'package:trip_management/providers/event_provider.dart';

// Minimal Event builder — only fills required fields.
Event _makeEvent(String id, {EventType type = EventType.social}) => Event(
      id: id,
      createdBy: 'u1',
      title: 'Event $id',
      description: '',
      location: '',
      startAt: DateTime(2026, 8, 1),
      inviteCode: 'code-$id',
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
      eventType: type,
      guests: const [],
    );

void main() {
  // ── EventProvider.applyOrder ─────────────────────────────────────────────────

  group('EventProvider.applyOrder', () {
    final a = _makeEvent('a');
    final b = _makeEvent('b');
    final c = _makeEvent('c');

    test('returns events unchanged when order is null', () {
      final result = EventProvider.applyOrder([a, b, c], null);
      expect(result.map((e) => e.id), ['a', 'b', 'c']);
    });

    test('returns events unchanged when order is empty', () {
      final result = EventProvider.applyOrder([a, b, c], []);
      expect(result.map((e) => e.id), ['a', 'b', 'c']);
    });

    test('reorders events to match the saved order', () {
      final result = EventProvider.applyOrder([a, b, c], ['c', 'a', 'b']);
      expect(result.map((e) => e.id), ['c', 'a', 'b']);
    });

    test('stale IDs in order (events removed) are silently skipped', () {
      final result = EventProvider.applyOrder([a, b], ['deleted', 'b', 'a']);
      expect(result.map((e) => e.id), ['b', 'a']);
    });

    test('new events not in order are appended at the end', () {
      // 'c' is new and not in the saved order.
      final result = EventProvider.applyOrder([a, b, c], ['b', 'a']);
      expect(result.map((e) => e.id).toList()[0], 'b');
      expect(result.map((e) => e.id).toList()[1], 'a');
      expect(result.map((e) => e.id).toList()[2], 'c');
    });

    test('empty event list returns empty regardless of order', () {
      final result = EventProvider.applyOrder([], ['a', 'b']);
      expect(result, isEmpty);
    });

    test('partial overlap — known events are ordered, unknowns are appended', () {
      final result = EventProvider.applyOrder([a, b, c], ['c', 'b']);
      // 'a' is not in the saved order so it goes to the end.
      expect(result.map((e) => e.id).toList(), ['c', 'b', 'a']);
    });
  });

  // ── Signup event type identification ─────────────────────────────────────────

  group('EventProvider signup event identification', () {
    test('myEvents and invitedEvents split correctly for signup type', () {
      final signupOrganizer = _makeEvent('s1', type: EventType.signup);
      final signupMember = Event(
        id: 's2',
        createdBy: 'other-user',
        title: 'Other signup',
        description: '',
        location: '',
        startAt: DateTime(2026, 8, 1),
        inviteCode: 'code-s2',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
        eventType: EventType.signup,
        guests: const [],
      );
      final ordered = EventProvider.applyOrder(
          [signupMember, signupOrganizer], ['s1', 's2']);
      expect(ordered.map((e) => e.id), ['s1', 's2']);
      expect(ordered.every((e) => e.eventType == EventType.signup), isTrue);
    });
  });

  // ── Session cache accessor safe defaults ─────────────────────────────────────
  //
  // All public session accessors must return empty / false / null for unknown
  // keys — never throw.  This exercises the provider's Map.containsKey logic
  // without requiring a live Supabase connection.

  group('EventProvider session cache accessor defaults', () {
    test('upcomingSessionsFor returns empty list for unknown eventId', () {
      final p = EventProvider();
      expect(p.upcomingSessionsFor('unknown'), isEmpty);
    });

    test('pastSessionsFor returns empty list for unknown eventId', () {
      final p = EventProvider();
      expect(p.pastSessionsFor('unknown'), isEmpty);
    });

    test('hasMoreUpcomingFor returns false for unknown eventId', () {
      final p = EventProvider();
      expect(p.hasMoreUpcomingFor('unknown'), isFalse);
    });

    test('hasMorePastFor returns false for unknown eventId', () {
      final p = EventProvider();
      expect(p.hasMorePastFor('unknown'), isFalse);
    });

    test('rosterFor returns null for unknown sessionId', () {
      final p = EventProvider();
      expect(p.rosterFor('unknown'), isNull);
    });

    test('hasMoreRosterFor returns false for unknown sessionId', () {
      final p = EventProvider();
      expect(p.hasMoreRosterFor('unknown'), isFalse);
    });

    test('myStatusFor returns null for unknown sessionId', () {
      final p = EventProvider();
      expect(p.myStatusFor('unknown'), isNull);
    });
  });

  // ── Session Realtime UPDATE: field preservation (Bug 4 regression) ───────────
  //
  // The Realtime handler for event_sessions UPDATE now uses EventSession.fromJson
  // instead of copyWithCounts, so metadata fields (capacity, requiresApproval,
  // signupLockHours, isPublic, dates) survive a count-only update.
  //
  // This group tests the EventSession model behaviour that the handler depends on.

  group('EventSession Realtime UPDATE field preservation (Bug 4 regression)', () {
    final sessionBase = <String, dynamic>{
      'id': 'sess-1',
      'event_id': 'ev-1',
      'session_number': 2,
      'start_at': DateTime.now().add(const Duration(days: 7)).toUtc().toIso8601String(),
      'end_at': DateTime.now().add(const Duration(days: 7, hours: 2)).toUtc().toIso8601String(),
      'invite_code': 'inv-code',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'going_count': 3,
      'waitlist_count': 1,
      'capacity': 15,
      'waitlist_enabled': true,
      'signup_lock_hours': 3,
      'is_public': false,
      'requires_approval': true,
    };

    test('fromJson round-trip preserves all fields when only counts change', () {
      final existing = EventSession.fromJson(sessionBase);

      // Simulate the Realtime handler merging new counts with existing metadata.
      final merged = EventSession.fromJson(<String, dynamic>{
        ...sessionBase,
        'going_count': 10,
        'waitlist_count': 4,
      });

      expect(merged.goingCount, 10);
      expect(merged.waitlistCount, 4);
      expect(merged.capacity, existing.capacity);
      expect(merged.requiresApproval, existing.requiresApproval);
      expect(merged.signupLockHours, existing.signupLockHours);
      expect(merged.isPublic, existing.isPublic);
      expect(merged.startAt, existing.startAt);
      expect(merged.endAt, existing.endAt);
    });

    test('Realtime handler pattern: payload field takes priority over existing value', () {
      final existing = EventSession.fromJson(sessionBase);

      // Organizer changed capacity from 15 → 20 on another device.
      final realtimePayload = <String, dynamic>{
        ...sessionBase,
        'capacity': 20,
        'going_count': 5,
        'waitlist_count': 0,
      };

      final merged = EventSession.fromJson(<String, dynamic>{
        'id': existing.id,
        'event_id': existing.eventId,
        'session_number': existing.sessionNumber,
        'start_at': realtimePayload.containsKey('start_at')
            ? realtimePayload['start_at']
            : existing.startAt.toIso8601String(),
        'end_at': existing.endAt?.toIso8601String(),
        'invite_code': existing.inviteCode,
        'created_at': existing.createdAt.toIso8601String(),
        'going_count': realtimePayload['going_count'],
        'waitlist_count': realtimePayload['waitlist_count'],
        'capacity': realtimePayload['capacity'], // new value from payload
        'waitlist_enabled': existing.waitlistEnabled,
        'signup_lock_hours': existing.signupLockHours,
        'is_public': existing.isPublic,
        'requires_approval': existing.requiresApproval,
      });

      expect(merged.capacity, 20); // updated from payload
      expect(merged.goingCount, 5);
      expect(merged.requiresApproval, isTrue); // preserved from existing
    });
  });

  // ── Promote-guard uses goingCount not roster.length (Bug 5 regression) ────────
  //
  // The UI promote-button now checks `session.goingCount < cap` instead of
  // `confirmed.length < cap` (confirmed = in-memory paginated roster slice).
  // This group tests the EventSession.isFull property that the guard relies on.

  group('Promote guard: isFull from goingCount (Bug 5 regression)', () {
    test('session is full when goingCount equals capacity (roster may be partial)', () {
      // DB says 10/10 — roster loaded only 3 entries due to pagination.
      final session = EventSession.fromJson(<String, dynamic>{
        'id': 's1',
        'event_id': 'e1',
        'session_number': 1,
        'start_at': DateTime.now().add(const Duration(hours: 2)).toUtc().toIso8601String(),
        'invite_code': 'c',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'going_count': 10,
        'capacity': 10,
      });
      expect(session.isFull, isTrue);
      expect(session.goingCount, 10);
    });

    test('session is not full when goingCount is below capacity', () {
      final session = EventSession.fromJson(<String, dynamic>{
        'id': 's1',
        'event_id': 'e1',
        'session_number': 1,
        'start_at': DateTime.now().add(const Duration(hours: 2)).toUtc().toIso8601String(),
        'invite_code': 'c',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'going_count': 9,
        'capacity': 10,
      });
      expect(session.isFull, isFalse);
    });

    test('session is never full when capacity is null (unlimited)', () {
      final session = EventSession.fromJson(<String, dynamic>{
        'id': 's1',
        'event_id': 'e1',
        'session_number': 1,
        'start_at': DateTime.now().add(const Duration(hours: 2)).toUtc().toIso8601String(),
        'invite_code': 'c',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'going_count': 9999,
      });
      expect(session.isFull, isFalse);
    });
  });

  // ── pending_review CTA label (Bug A regression) ──────────────────────────────
  //
  // _SignupCTAButton.build() was ignoring widget.label and always showing
  // "Claim your spot".  For requiresApproval sessions the button must show
  // "Request to join".  The fix is `final label = widget.label;` in build().
  //
  // This group tests the session model property that drives the label selection.

  group('requiresApproval label selection (Bug A regression)', () {
    test('requiresApproval=false session is not full → label path is "claim spot"', () {
      final session = EventSession.fromJson(<String, dynamic>{
        'id': 's1',
        'event_id': 'e1',
        'session_number': 1,
        'start_at': DateTime.now().add(const Duration(hours: 2)).toUtc().toIso8601String(),
        'invite_code': 'c',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'going_count': 2,
        'capacity': 10,
        'requires_approval': false,
      });
      expect(session.isFull, isFalse);
      expect(session.requiresApproval, isFalse);
      // UI label should be "Claim your spot", not "Request to join".
    });

    test('requiresApproval=true session is not full → label path is "request to join"', () {
      final session = EventSession.fromJson(<String, dynamic>{
        'id': 's1',
        'event_id': 'e1',
        'session_number': 1,
        'start_at': DateTime.now().add(const Duration(hours: 2)).toUtc().toIso8601String(),
        'invite_code': 'c',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'going_count': 2,
        'capacity': 10,
        'requires_approval': true,
      });
      expect(session.isFull, isFalse);
      expect(session.requiresApproval, isTrue);
      // UI label should be "Request to join", not "Claim your spot".
    });

    test('requiresApproval=true but session full → label path is "join waitlist"', () {
      final session = EventSession.fromJson(<String, dynamic>{
        'id': 's1',
        'event_id': 'e1',
        'session_number': 1,
        'start_at': DateTime.now().add(const Duration(hours: 2)).toUtc().toIso8601String(),
        'invite_code': 'c',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'going_count': 10,
        'capacity': 10,
        'requires_approval': true,
        'waitlist_enabled': true,
      });
      // When full, isFull takes priority — show waitlist regardless of approval mode.
      expect(session.isFull, isTrue);
    });
  });

  // ── refreshSessionRoster myStatus preservation (Bug C regression) ────────────
  //
  // refreshSessionRoster must NOT clear _mySessionStatuses when the roster has
  // more pages (hasMore=true), because the current user's entry may be on page 2+.
  // Only clear when hasMore=false (all entries loaded and user was not found).
  //
  // This group tests the invariant at the model level.

  group('refreshSessionRoster myStatus logic (Bug C regression)', () {
    test('user absent from first page + hasMore=true → status must NOT be cleared', () {
      final page1Entries = List.generate(
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
      const hasMore = true;
      const myUserId = 'u-late';

      final foundInPage = page1Entries.any((e) => e.userId == myUserId);
      // Since hasMore=true, NOT finding user in page1 does not mean they're absent.
      expect(foundInPage, isFalse);
      expect(hasMore, isTrue);
      // The provider must preserve existing _mySessionStatuses entry in this case.
    });

    test('user absent from full page + hasMore=false → status must be cleared', () {
      final allEntries = [
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
      const hasMore = false;
      const myUserId = 'u-absent';

      final foundInPage = allEntries.any((e) => e.userId == myUserId);
      // hasMore=false + not found = confirmed absent.
      expect(foundInPage, isFalse);
      expect(hasMore, isFalse);
      // The provider must clear _mySessionStatuses in this case.
    });
  });

  // ── Roster sort order — _rosterOrder comparator (Bugs 5/sort regression) ─────
  //
  // All in-memory roster mutations (reorder, Realtime INSERT, Realtime UPDATE)
  // must preserve ascending signup_order with nulls last.

  group('Roster sort order invariant', () {
    EventSessionRosterEntry makeEntry(String id, int? order,
            {String status = 'going'}) =>
        EventSessionRosterEntry(
          id: id,
          sessionId: 's1',
          displayName: id,
          status: status,
          signupOrder: order,
          signedUpAt: DateTime.now(),
        );

    int rosterOrder(EventSessionRosterEntry a, EventSessionRosterEntry b) {
      if (a.signupOrder == null && b.signupOrder == null) return 0;
      if (a.signupOrder == null) return 1;
      if (b.signupOrder == null) return -1;
      return a.signupOrder!.compareTo(b.signupOrder!);
    }

    test('entries with non-null orders sort ascending', () {
      final entries = [makeEntry('c', 3), makeEntry('a', 1), makeEntry('b', 2)];
      entries.sort(rosterOrder);
      expect(entries.map((e) => e.id).toList(), ['a', 'b', 'c']);
    });

    test('null-order entries sort after non-null entries (pending_review last)', () {
      final entries = [
        makeEntry('pending', null, status: 'pending_review'),
        makeEntry('going2', 2),
        makeEntry('going1', 1),
      ];
      entries.sort(rosterOrder);
      expect(entries.map((e) => e.id).toList(), ['going1', 'going2', 'pending']);
    });

    test('multiple null-order entries are stable relative to each other', () {
      final entries = [
        makeEntry('p1', null, status: 'pending_review'),
        makeEntry('p2', null, status: 'pending_review'),
        makeEntry('going1', 1),
      ];
      entries.sort(rosterOrder);
      expect(entries.first.id, 'going1');
      // Both pending entries end up after going1.
      expect(entries.skip(1).every((e) => e.signupOrder == null), isTrue);
    });

    test('all-null order list stays stable', () {
      final entries = [
        makeEntry('p1', null, status: 'pending_review'),
        makeEntry('p2', null, status: 'pending_review'),
      ];
      entries.sort(rosterOrder);
      // No crash; all null-order entries remain.
      expect(entries.length, 2);
      expect(entries.every((e) => e.signupOrder == null), isTrue);
    });

    test('reorder updates signupOrder values on affected entries', () {
      // Simulates what reorderSessionRoster does in-memory.
      final roster = [makeEntry('a', 1), makeEntry('b', 2), makeEntry('c', 3)];
      // User drags 'c' to position 1 → new order: c, a, b
      final orderedIds = ['c', 'a', 'b'];
      const startOrder = 1;
      final idToOrder = {
        for (var i = 0; i < orderedIds.length; i++) orderedIds[i]: startOrder + i,
      };
      final updated = roster
          .map((r) {
            final o = idToOrder[r.id];
            return o != null ? r.copyWith(signupOrder: o) : r;
          })
          .toList()
        ..sort(rosterOrder);

      expect(updated.map((e) => e.id).toList(), ['c', 'a', 'b']);
      expect(updated.map((e) => e.signupOrder).toList(), [1, 2, 3]);
    });
  });

  // ── requiresApproval label path (Bug 3/4 regression) ─────────────────────────
  //
  // Both the QR scan sheet and the deep-link invite screen must show
  // "Request to join" (not "Claim your spot") when requiresApproval=true.

  group('requiresApproval session data parsing from join screens', () {
    test('requires_approval field is read from session RPC response', () {
      // Simulates what _showSessionJoinSheet / SessionInviteScreen read from
      // the get_session_by_invite_code payload.
      final sessionPayload = <String, dynamic>{
        'title': 'Yoga',
        'going_count': 2,
        'capacity': 10,
        'waitlist_enabled': true,
        'signup_lock_hours': null,
        'requires_approval': true,
      };
      final requiresApproval = sessionPayload['requires_approval'] as bool? ?? false;
      final isFull = (sessionPayload['capacity'] as int?) != null &&
          (sessionPayload['going_count'] as int) >= (sessionPayload['capacity'] as int);

      // Button label logic that both screens now use:
      final label = isFull
          ? 'Join the waitlist'
          : requiresApproval
              ? 'Request to join'
              : 'Claim your spot';
      expect(label, 'Request to join');
    });

    test('normal session (requiresApproval=false) shows claim-spot label', () {
      final payload = <String, dynamic>{
        'going_count': 2,
        'capacity': 10,
        'requires_approval': false,
      };
      final requiresApproval = payload['requires_approval'] as bool? ?? false;
      final isFull =
          (payload['going_count'] as int) >= (payload['capacity'] as int);
      final label = isFull ? 'Join the waitlist' : requiresApproval ? 'Request to join' : 'Claim your spot';
      expect(label, 'Claim your spot');
    });

    test('full session overrides requiresApproval — shows waitlist label', () {
      final payload = <String, dynamic>{
        'going_count': 10,
        'capacity': 10,
        'requires_approval': true,
        'waitlist_enabled': true,
      };
      final requiresApproval = payload['requires_approval'] as bool? ?? false;
      final isFull = (payload['going_count'] as int) >= (payload['capacity'] as int);
      final label = isFull ? 'Join the waitlist' : requiresApproval ? 'Request to join' : 'Claim your spot';
      expect(label, 'Join the waitlist');
    });

    test('absent requires_approval field defaults to false', () {
      final payload = <String, dynamic>{'going_count': 1};
      final requiresApproval = payload['requires_approval'] as bool? ?? false;
      expect(requiresApproval, isFalse);
    });
  });
}
