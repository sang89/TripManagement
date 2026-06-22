import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/event.dart';
import 'package:trip_management/models/event_session.dart';
import 'package:trip_management/models/live_queue_item.dart';

Event _event({
  required String id,
  required DateTime startAt,
  DateTime? endAt,
  String createdBy = 'u1',
}) =>
    Event(
      id: id,
      createdBy: createdBy,
      title: 'Event $id',
      description: '',
      location: '',
      startAt: startAt,
      endAt: endAt,
      inviteCode: 'code-$id',
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
      guests: const [],
    );

EventSession _session({
  required String id,
  required String eventId,
  required DateTime startAt,
  DateTime? endAt,
}) =>
    EventSession(
      id: id,
      eventId: eventId,
      sessionNumber: 1,
      startAt: startAt,
      endAt: endAt,
      inviteCode: 'sc-$id',
      createdAt: DateTime(2026, 6, 1),
    );

void main() {
  // Use the real clock: Event.isPastFor() internally calls DateTime.now(), so a
  // fixed timestamp would drift past the events' endAt and make them "past".
  final now = DateTime.now();

  group('buildLiveQueue', () {
    test('ongoing event with NO live session → Info-tab item', () {
      final ongoing = _event(
        id: 'a',
        startAt: now.subtract(const Duration(hours: 1)),
        endAt: now.add(const Duration(hours: 1)),
      );
      final past = _event(
        id: 'b',
        startAt: now.subtract(const Duration(days: 2)),
        endAt: now.subtract(const Duration(days: 1)),
      );
      final future = _event(
        id: 'c',
        startAt: now.add(const Duration(days: 1)),
        endAt: now.add(const Duration(days: 2)),
      );

      final q = buildLiveQueue([ongoing, past, future], const [], 'u1', now);

      expect(q.map((i) => i.eventId), ['a']);
      expect(q.single.isSession, isFalse);
      expect(q.single.route, '/event/a'); // Info → Details
    });

    test('event with null endAt is ongoing once it has started', () {
      final e = _event(id: 'a', startAt: now.subtract(const Duration(hours: 1)));
      final q = buildLiveQueue([e], const [], 'u1', now);
      expect(q.map((i) => i.eventId), ['a']);
      expect(q.single.isSession, isFalse);
    });

    test('live session → Activity-tab item', () {
      final e = _event(
        id: 'a',
        startAt: now.subtract(const Duration(days: 1)),
        endAt: now.add(const Duration(days: 10)),
      );
      final s = _session(
        id: 's1',
        eventId: 'a',
        startAt: now.subtract(const Duration(minutes: 5)),
        endAt: now.add(const Duration(minutes: 55)),
      );

      final q = buildLiveQueue([e], [s], 'u1', now);

      expect(q.length, 1);
      expect(q.single.isSession, isTrue);
      expect(q.single.sessionId, 's1');
      expect(q.single.title, 'Event a');
      expect(q.single.route, '/event/a?tab=session&sessionId=s1');
    });

    test('signup event WITH a live session: only the session (no Info entry)', () {
      // Event "a" is ongoing AND has a live session → only the session item.
      // Event "b" is ongoing with NO session → its own Info item.
      final a = _event(
        id: 'a',
        startAt: now.subtract(const Duration(hours: 1)),
        endAt: now.add(const Duration(hours: 1)),
      );
      final b = _event(
        id: 'b',
        startAt: now.subtract(const Duration(hours: 1)),
        endAt: now.add(const Duration(hours: 1)),
      );
      final s = _session(
        id: 's1',
        eventId: 'a',
        startAt: now.subtract(const Duration(minutes: 5)),
        endAt: now.add(const Duration(minutes: 55)),
      );

      final q = buildLiveQueue([a, b], [s], 'u1', now);

      expect(q.length, 2);
      final aItem = q.firstWhere((i) => i.eventId == 'a');
      final bItem = q.firstWhere((i) => i.eventId == 'b');
      expect(aItem.isSession, isTrue); // Activity tab
      expect(bItem.isSession, isFalse); // Info tab
      expect(bItem.route, '/event/b');
    });

    test('one event with multiple live sessions yields one item per session', () {
      final a = _event(
        id: 'A',
        startAt: now.subtract(const Duration(hours: 2)),
        endAt: now.add(const Duration(hours: 2)),
      );
      final x = _session(
        id: 'X',
        eventId: 'A',
        startAt: now.subtract(const Duration(minutes: 30)),
        endAt: now.add(const Duration(minutes: 30)),
      );
      final y = _session(
        id: 'Y',
        eventId: 'A',
        startAt: now.subtract(const Duration(minutes: 10)),
        endAt: now.add(const Duration(minutes: 50)),
      );

      final q = buildLiveQueue([a], [x, y], 'u1', now);

      expect(q.length, 2);
      expect(q.every((i) => i.isSession && i.eventId == 'A'), isTrue);
      expect(q[0].sessionId, 'X');
      expect(q[1].sessionId, 'Y');
    });

    test('sessions are prioritised first, even when they start later', () {
      // The plain event STARTED EARLIER than the session, but the session must
      // still come first (sessions before events), then by start time.
      final earlyEvent = _event(
        id: 'earlyEvent',
        startAt: now.subtract(const Duration(hours: 3)),
        endAt: now.add(const Duration(hours: 1)),
      );
      final sessionEvent = _event(
        id: 'sEvt',
        startAt: now.subtract(const Duration(days: 1)),
        endAt: now.add(const Duration(days: 1)),
      );
      final lateSession = _session(
        id: 'lateSession',
        eventId: 'sEvt',
        startAt: now.subtract(const Duration(minutes: 5)),
        endAt: now.add(const Duration(hours: 1)),
      );

      final q = buildLiveQueue(
          [earlyEvent, sessionEvent], [lateSession], 'u1', now);

      expect(q[0].isSession, isTrue); // session first
      expect(q[0].sessionId, 'lateSession');
      expect(q[1].isSession, isFalse); // event after
      expect(q[1].eventId, 'earlyEvent');
    });

    test('empty when nothing is live', () {
      final future = _event(
        id: 'c',
        startAt: now.add(const Duration(days: 1)),
        endAt: now.add(const Duration(days: 2)),
      );
      expect(buildLiveQueue([future], const [], 'u1', now), isEmpty);
    });
  });
}
