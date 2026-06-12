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
    'status': 'going',
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
      expect(g.status, 'going');
    });

    test('defaults status to going when missing', () {
      final j = Map<String, dynamic>.from(guestJson)..remove('status');
      final g = EventGuest.fromJson(j);
      expect(g.status, 'going');
    });

    test('copyWith updates status only', () {
      final g = EventGuest.fromJson(guestJson);
      final updated = g.copyWith(status: 'maybe');
      expect(updated.status, 'maybe');
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
    final now = DateTime.now();

    setUp(() {
      event = Event.fromJson(eventJson).copyWith(guests: [
        EventGuest(
          id: 'g1',
          eventId: 'e1',
          userId: 'u2',
          displayName: 'Alice',
          status: 'going',
          rsvpAt: now,
          createdAt: now,
        ),
        EventGuest(
          id: 'g2',
          eventId: 'e1',
          userId: 'u3',
          displayName: 'Bob',
          status: 'maybe',
          rsvpAt: now,
          createdAt: now,
        ),
        EventGuest(
          id: 'g3',
          eventId: 'e1',
          userId: 'u4',
          displayName: 'Carol',
          status: 'declined',
          rsvpAt: now,
          createdAt: now,
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

  // ── EventType ────────────────────────────────────────────────────────────────

  group('EventType.fromString', () {
    test('parses all known types', () {
      expect(EventType.fromString('trip'), EventType.trip);
      expect(EventType.fromString('birthday'), EventType.birthday);
      expect(EventType.fromString('wedding'), EventType.wedding);
      expect(EventType.fromString('quick_bites'), EventType.quickBites);
      expect(EventType.fromString('signup'), EventType.signup);
      expect(EventType.fromString('social'), EventType.social);
    });

    test('defaults unknown or null values to social', () {
      expect(EventType.fromString(null), EventType.social);
      expect(EventType.fromString(''), EventType.social);
      expect(EventType.fromString('unknown'), EventType.social);
    });

    test('dbValue round-trips back to fromString', () {
      for (final type in EventType.values) {
        expect(EventType.fromString(type.dbValue), type);
      }
    });
  });

  // ── Signup-specific Event fields ─────────────────────────────────────────────

  final signupEventJson = {
    'id': 'e2',
    'created_by': 'u1',
    'title': 'Yoga class',
    'description': 'Weekly yoga',
    'location': 'Studio A',
    'start_at': '2026-08-01T09:00:00.000Z',
    'event_type': 'signup',
    'waitlist_enabled': true,
    'signup_lock_hours': 4,
    'invite_code': 'yoga-code',
    'created_at': '2026-06-01T08:00:00.000Z',
    'updated_at': '2026-06-01T08:00:00.000Z',
    'event_guests': <dynamic>[],
  };

  group('Event signup fields', () {
    test('fromJson parses waitlistEnabled and signupLockHours', () {
      final e = Event.fromJson(signupEventJson);
      expect(e.eventType, EventType.signup);
      expect(e.waitlistEnabled, isTrue);
      expect(e.signupLockHours, 4);
    });

    test('fromJson defaults waitlistEnabled=true when absent', () {
      final j = Map<String, dynamic>.from(signupEventJson)
        ..remove('waitlist_enabled');
      expect(Event.fromJson(j).waitlistEnabled, isTrue);
    });

    test('fromJson parses waitlistEnabled=false', () {
      final j = Map<String, dynamic>.from(signupEventJson)
        ..['waitlist_enabled'] = false;
      expect(Event.fromJson(j).waitlistEnabled, isFalse);
    });

    test('isSignup true only for signup type', () {
      final signup = Event.fromJson(signupEventJson);
      expect(signup.isSignup, isTrue);
      expect(signup.isTrip, isFalse);
      expect(signup.isBirthday, isFalse);
      expect(signup.isQuickBites, isFalse);
    });

    test('isSignupLocked false when no lock hours set', () {
      final j = Map<String, dynamic>.from(signupEventJson)
        ..remove('signup_lock_hours');
      expect(Event.fromJson(j).isSignupLocked, isFalse);
    });

    test('isSignupLocked false when start is far in future', () {
      final startAt =
          DateTime.now().toUtc().add(const Duration(hours: 10)).toIso8601String();
      final j = Map<String, dynamic>.from(signupEventJson)
        ..['start_at'] = startAt
        ..['signup_lock_hours'] = 2;
      expect(Event.fromJson(j).isSignupLocked, isFalse);
    });

    test('isSignupLocked true when within lock window', () {
      final startAt =
          DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String();
      final j = Map<String, dynamic>.from(signupEventJson)
        ..['start_at'] = startAt
        ..['signup_lock_hours'] = 2;
      expect(Event.fromJson(j).isSignupLocked, isTrue);
    });

    test('toJson includes waitlist_enabled and signup_lock_hours for signup type', () {
      final e = Event.fromJson(signupEventJson);
      final json = e.toJson();
      expect(json['waitlist_enabled'], isTrue);
      expect(json['signup_lock_hours'], 4);
      expect(json['event_type'], 'signup');
    });

    test('toJson omits waitlist_enabled and signup_lock_hours for non-signup type', () {
      final e = Event.fromJson(eventJson); // birthday party (social)
      final json = e.toJson();
      expect(json.containsKey('waitlist_enabled'), isFalse);
      expect(json.containsKey('signup_lock_hours'), isFalse);
    });

    test('copyWith updates waitlistEnabled and clears signupLockHours', () {
      final e = Event.fromJson(signupEventJson);
      final updated = e.copyWith(
        waitlistEnabled: false,
        clearSignupLockHours: true,
      );
      expect(updated.waitlistEnabled, isFalse);
      expect(updated.signupLockHours, isNull);
      expect(updated.eventType, EventType.signup);
    });
  });

  // ── Event guest count helpers ─────────────────────────────────────────────────

  group('Event guest counts', () {
    test('waitlistCount counts waitlisted guests', () {
      final now = DateTime.now();
      final guests = [
        EventGuest(
          id: 'g1', eventId: 'e1', displayName: 'A',
          status: 'waitlisted', rsvpAt: now, createdAt: now,
        ),
        EventGuest(
          id: 'g2', eventId: 'e1', displayName: 'B',
          status: 'going', rsvpAt: now, createdAt: now,
        ),
        EventGuest(
          id: 'g3', eventId: 'e1', displayName: 'C',
          status: 'waitlisted', rsvpAt: now, createdAt: now,
        ),
      ];
      final e = Event.fromJson(eventJson).copyWith(guests: guests);
      expect(e.waitlistCount, 2);
      expect(e.goingCount, 1);
    });

    test('pendingCount counts pending guests', () {
      final now = DateTime.now();
      final guests = [
        EventGuest(
          id: 'g1', eventId: 'e1', displayName: 'A',
          status: 'pending', rsvpAt: now, createdAt: now,
        ),
        EventGuest(
          id: 'g2', eventId: 'e1', displayName: 'B',
          status: 'accepted', rsvpAt: now, createdAt: now,
        ),
      ];
      final e = Event.fromJson(eventJson).copyWith(guests: guests);
      expect(e.pendingCount, 1);
      expect(e.goingCount, 1); // 'accepted' counts as going
    });
  });
}
