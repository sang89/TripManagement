// Regression tests for queue duplicate-slot bugs.
//
// Bug (June 2026): The member picker only filtered OUT users who had a userId
// matching an existing slot entry.  Anonymous guests (userId == null) were
// NEVER filtered — so the same person (e.g. "BC") could be added to two spots
// in the same queue row via "Add a teammate".  The DB's add_member_to_queue
// also lacked an anonymous-guest guard, so the duplicate survived a server
// round-trip too.
//
// Fix:
//   • UI  — also build alreadyInSlotNames from entries where userId IS NULL;
//            anonymous guests whose lowercased displayName appears in that set
//            are excluded from the picker candidates.
//   • DB  — add_member_to_queue now raises 'already_in_queue' when p_user_id
//            IS NULL and LOWER(TRIM(display_name)) already exists for that
//            activity.
//
// HOW TO READ A FAILURE HERE
//   A failure means the candidate filter is broken.  Do not ship until the
//   filtering logic exactly matches the query below.

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/event_guest.dart';
import 'package:trip_management/models/session_queue.dart';

// ─── Pure function mirroring _QueueSpotRowState._showMemberPicker logic ───────
//
// Kept in sync with event_detail_screen.dart:_showMemberPicker.
// If you change the production filter, update this function too.

List<EventGuest> buildPickerCandidates({
  required List<EventGuest> guests,
  required List<SessionQueueEntry> entries,
}) {
  final alreadyInSlot = entries
      .where((e) => e.userId != null)
      .map((e) => e.userId!)
      .toSet();

  final alreadyInSlotNames = entries
      .where((e) => e.userId == null)
      .map((e) => e.displayName.toLowerCase())
      .toSet();

  return guests
      .where((g) => !const {'left', 'declined'}.contains(g.status))
      .where((g) {
        if (g.userId != null) return !alreadyInSlot.contains(g.userId);
        return !alreadyInSlotNames.contains(g.displayName.toLowerCase());
      })
      .toList();
}

// ─── Test helpers ──────────────────────────────────────────────────────────────

EventGuest _appGuest({
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

EventGuest _anonGuest({
  required String id,
  required String displayName,
  String status = 'going',
}) =>
    EventGuest(
      id: id,
      eventId: 'ev1',
      userId: null,
      displayName: displayName,
      status: status,
      rsvpAt: DateTime(2026, 6, 1),
      createdAt: DateTime(2026, 6, 1),
    );

SessionQueueEntry _entry({
  String id = 'e1',
  String? userId,
  required String displayName,
  int position = 1,
}) =>
    SessionQueueEntry(
      id: id,
      activityId: 'act1',
      userId: userId,
      displayName: displayName,
      status: QueueEntryStatus.playing,
      queuePosition: position,
      joinedAt: DateTime(2026, 6, 16),
    );

// ─── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('buildPickerCandidates — anonymous guest duplicate prevention', () {
    test('regression: same anonymous guest can NOT appear twice in one slot', () {
      // BC (no account) is already in position 1.
      final entries = [_entry(userId: null, displayName: 'BC')];
      final guests  = [_anonGuest(id: 'g-bc', displayName: 'BC')];

      final candidates = buildPickerCandidates(guests: guests, entries: entries);

      // BC must NOT show up in the picker — this was the bug.
      expect(candidates, isEmpty,
          reason: 'An anonymous guest already in this slot must be filtered out');
    });

    test('case-insensitive match blocks "bc" when "BC" is in slot', () {
      final entries = [_entry(userId: null, displayName: 'BC')];
      final guests  = [_anonGuest(id: 'g-bc', displayName: 'bc')];

      expect(buildPickerCandidates(guests: guests, entries: entries), isEmpty);
    });

    test('different anonymous guest IS still shown', () {
      final entries   = [_entry(userId: null, displayName: 'BC')];
      final candidates = buildPickerCandidates(
        guests: [
          _anonGuest(id: 'g-bc', displayName: 'BC'),
          _anonGuest(id: 'g-am', displayName: 'AM'),
        ],
        entries: entries,
      );

      expect(candidates.map((g) => g.displayName), containsAll(['AM']));
      expect(candidates.map((g) => g.displayName), isNot(contains('BC')));
    });

    test('slot with no anonymous entries shows all anonymous guests', () {
      final candidates = buildPickerCandidates(
        guests: [
          _anonGuest(id: 'g1', displayName: 'Alice'),
          _anonGuest(id: 'g2', displayName: 'Bob'),
        ],
        entries: [],
      );
      expect(candidates.length, 2);
    });
  });

  group('buildPickerCandidates — app user duplicate prevention', () {
    test('app user already in slot is excluded', () {
      final entries = [_entry(id: 'e1', userId: 'u1', displayName: 'Alice')];
      final guests  = [_appGuest(id: 'g1', userId: 'u1', displayName: 'Alice')];

      expect(buildPickerCandidates(guests: guests, entries: entries), isEmpty);
    });

    test('different app user is still shown', () {
      final entries    = [_entry(userId: 'u1', displayName: 'Alice')];
      final candidates = buildPickerCandidates(
        guests: [
          _appGuest(id: 'g1', userId: 'u1', displayName: 'Alice'),
          _appGuest(id: 'g2', userId: 'u2', displayName: 'Bob'),
        ],
        entries: entries,
      );
      expect(candidates.map((g) => g.userId), contains('u2'));
      expect(candidates.map((g) => g.userId), isNot(contains('u1')));
    });

    test('app user entry does NOT block anonymous guest with same display name', () {
      // An app user named "BC" in the slot must not block the anonymous "BC"
      // guest from appearing in the picker — they are different people.
      final entries = [_entry(userId: 'u1', displayName: 'BC')];
      final guests  = [_anonGuest(id: 'g-bc', displayName: 'BC')];

      final candidates = buildPickerCandidates(guests: guests, entries: entries);

      // Anonymous BC is a different person → should still appear.
      expect(candidates.length, 1);
      expect(candidates.first.userId, isNull);
    });
  });

  group('buildPickerCandidates — status filtering', () {
    test('declined guests are excluded regardless of slot state', () {
      final candidates = buildPickerCandidates(
        guests: [
          _anonGuest(id: 'g1', displayName: 'Alice', status: 'declined'),
          _anonGuest(id: 'g2', displayName: 'Bob',   status: 'left'),
          _anonGuest(id: 'g3', displayName: 'Carol', status: 'going'),
        ],
        entries: [],
      );
      expect(candidates.map((g) => g.displayName), equals(['Carol']));
    });
  });

  group('buildPickerCandidates — mixed scenarios', () {
    test('slot with both app user and anonymous entry filters both correctly', () {
      final entries = [
        _entry(id: 'e1', userId: 'u1', displayName: 'Alice'),
        _entry(id: 'e2', userId: null,  displayName: 'BC'),
      ];
      final candidates = buildPickerCandidates(
        guests: [
          _appGuest(id: 'g1', userId: 'u1', displayName: 'Alice'), // in slot
          _anonGuest(id: 'g2', displayName: 'BC'),                 // in slot
          _appGuest(id: 'g3', userId: 'u2', displayName: 'Carol'), // free
          _anonGuest(id: 'g4', displayName: 'Dave'),               // free
        ],
        entries: entries,
      );

      final names = candidates.map((g) => g.displayName).toList();
      expect(names, containsAll(['Carol', 'Dave']));
      expect(names, isNot(contains('Alice')));
      expect(names, isNot(contains('BC')));
    });
  });
}
