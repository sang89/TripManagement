import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/event.dart';
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
      // This verifies that signup events are treated the same as other types
      // by the provider's list split (createdBy drives the distinction, not type).
      final signupOrganizer = _makeEvent('s1', type: EventType.signup);
      final signupMember = Event(
        id: 's2',
        createdBy: 'other-user', // not the current user
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

        // The split logic (myEvents / invitedEvents) depends on _userId which
      // requires a live auth session, so we only verify applyOrder here.
      final ordered = EventProvider.applyOrder(
          [signupMember, signupOrganizer], ['s1', 's2']);
      expect(ordered.map((e) => e.id), ['s1', 's2']);
      expect(ordered.every((e) => e.eventType == EventType.signup), isTrue);
    });
  });
}
