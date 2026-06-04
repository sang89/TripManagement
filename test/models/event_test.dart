import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/event.dart';
import 'package:trip_management/models/event_guest.dart';

void main() {
  final guestJson = {
    'id': 'g1',
    'event_id': 'e1',
    'user_id': 'u2',
    'display_name': 'Alice',
    'email': 'alice@example.com',
    'phone': null,
    'rsvp_status': 'going',
    'rsvp_at': '2026-06-01T09:00:00.000Z',
    'created_at': '2026-06-01T08:00:00.000Z',
  };

  final eventJson = {
    'id': 'e1',
    'created_by': 'u1',
    'title': 'Birthday Party',
    'description': 'Let\'s celebrate!',
    'location': 'Central Park, NY',
    'location_lat': 40.785091,
    'location_lng': -73.968285,
    'start_at': '2026-07-04T18:00:00.000Z',
    'end_at': '2026-07-04T22:00:00.000Z',
    'capacity': 50,
    'invite_code': 'abc-123',
    'created_at': '2026-06-01T08:00:00.000Z',
    'updated_at': '2026-06-01T08:00:00.000Z',
    'event_guests': [guestJson],
  };

  group('EventGuest.fromJson', () {
    test('parses all fields', () {
      final g = EventGuest.fromJson(guestJson);
      expect(g.id, 'g1');
      expect(g.eventId, 'e1');
      expect(g.userId, 'u2');
      expect(g.displayName, 'Alice');
      expect(g.email, 'alice@example.com');
      expect(g.phone, isNull);
      expect(g.rsvpStatus, 'going');
    });

    test('defaults rsvp_status to going when missing', () {
      final j = Map<String, dynamic>.from(guestJson)..remove('rsvp_status');
      final g = EventGuest.fromJson(j);
      expect(g.rsvpStatus, 'going');
    });

    test('copyWith updates rsvpStatus only', () {
      final g = EventGuest.fromJson(guestJson);
      final updated = g.copyWith(rsvpStatus: 'maybe');
      expect(updated.rsvpStatus, 'maybe');
      expect(updated.id, g.id);
      expect(updated.displayName, g.displayName);
    });
  });

  group('Event.fromJson', () {
    test('parses all fields including nested guests', () {
      final e = Event.fromJson(eventJson);
      expect(e.id, 'e1');
      expect(e.createdBy, 'u1');
      expect(e.title, 'Birthday Party');
      expect(e.description, 'Let\'s celebrate!');
      expect(e.location, 'Central Park, NY');
      expect(e.locationLat, closeTo(40.785091, 0.0001));
      expect(e.locationLng, closeTo(-73.968285, 0.0001));
      expect(e.startAt, DateTime.utc(2026, 7, 4, 18));
      expect(e.endAt, DateTime.utc(2026, 7, 4, 22));
      expect(e.capacity, 50);
      expect(e.inviteCode, 'abc-123');
      expect(e.guests.length, 1);
      expect(e.guests.first.displayName, 'Alice');
    });

    test('handles optional fields absent', () {
      final j = Map<String, dynamic>.from(eventJson)
        ..remove('end_at')
        ..remove('capacity')
        ..remove('location_lat')
        ..remove('location_lng')
        ..remove('event_guests');
      final e = Event.fromJson(j);
      expect(e.endAt, isNull);
      expect(e.capacity, isNull);
      expect(e.locationLat, isNull);
      expect(e.guests, isEmpty);
    });
  });

  group('Event computed properties', () {
    late Event event;

    setUp(() {
      event = Event.fromJson(eventJson).copyWith(guests: [
        EventGuest(
          id: 'g1',
          eventId: 'e1',
          userId: 'u2',
          displayName: 'Alice',
          rsvpStatus: 'going',
          rsvpAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),
        EventGuest(
          id: 'g2',
          eventId: 'e1',
          userId: 'u3',
          displayName: 'Bob',
          rsvpStatus: 'maybe',
          rsvpAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),
        EventGuest(
          id: 'g3',
          eventId: 'e1',
          userId: 'u4',
          displayName: 'Carol',
          rsvpStatus: 'declined',
          rsvpAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      ]);
    });

    test('counts going, maybe, declined', () {
      expect(event.goingCount, 1);
      expect(event.maybeCount, 1);
      expect(event.declinedCount, 1);
    });

    test('isFull when going >= capacity', () {
      final full = event.copyWith(capacity: 1);
      expect(full.isFull, isTrue);
    });

    test('not full when capacity is null', () {
      final unlimited = event.copyWith(clearCapacity: true);
      expect(unlimited.isFull, isFalse);
    });

    test('not full when going < capacity', () {
      final partial = event.copyWith(capacity: 5);
      expect(partial.isFull, isFalse);
    });
  });

  group('Event.copyWith', () {
    test('clears nullable fields with clear flags', () {
      final e = Event.fromJson(eventJson);
      expect(e.endAt, isNotNull);
      final cleared = e.copyWith(clearEndAt: true);
      expect(cleared.endAt, isNull);
      expect(cleared.capacity, isNotNull);
      final cleared2 = cleared.copyWith(clearCapacity: true);
      expect(cleared2.capacity, isNull);
    });

    test('preserves unchanged fields', () {
      final e = Event.fromJson(eventJson);
      final copy = e.copyWith(title: 'New Title');
      expect(copy.title, 'New Title');
      expect(copy.location, e.location);
      expect(copy.guests.length, e.guests.length);
    });
  });
}
