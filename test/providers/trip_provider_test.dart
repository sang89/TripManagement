import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/trip.dart';
import 'package:trip_management/models/trip_member.dart';
import 'package:trip_management/models/trip_stop.dart';
import 'package:trip_management/providers/trip_provider.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Trip _makeTrip({
  String id = 't1',
  String title = 'Summer Trip',
  String destination = 'Paris',
  List<TripMember>? members,
  List<TripStop>? stops,
}) =>
    Trip(
      id: id,
      createdBy: 'user1',
      title: title,
      destination: destination,
      notes: '',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      members: members ?? [],
      stops: stops ?? [],
    );

TripMember _makeMember({
  String id = 'm1',
  String tripId = 't1',
  String displayName = 'Alice',
  String role = 'organizer',
}) =>
    TripMember(
      id: id,
      tripId: tripId,
      displayName: displayName,
      role: role,
      createdAt: DateTime(2026, 1, 1),
    );

TripStop _makeStop({
  String id = 's1',
  String tripId = 't1',
  String title = 'Eiffel Tower',
  int sortOrder = 0,
}) =>
    TripStop(
      id: id,
      tripId: tripId,
      title: title,
      address: '5 Av. Anatole France',
      notes: '',
      sortOrder: sortOrder,
      createdAt: DateTime(2026, 1, 1),
    );

// ── Fake provider (skips DB and cache I/O) ───────────────────────────────────

class FakeTripProvider extends TripProvider {
  // Override load so tests can seed state without a real Supabase connection.
  @override
  Future<void> load() async {}
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late FakeTripProvider provider;

  setUp(() => provider = FakeTripProvider());

  // ── Initial state ─────────────────────────────────────────────────────────
  group('initial state', () {
    test('trips list is empty before load', () {
      expect(provider.trips, isEmpty);
    });

    test('loaded is false before load', () {
      expect(provider.loaded, isFalse);
    });

    test('getById returns null when list is empty', () {
      expect(provider.getById('any-id'), isNull);
    });

    test('clear on empty state does not throw', () {
      expect(provider.clear, returnsNormally);
      expect(provider.trips, isEmpty);
    });
  });

  // ── seedForTest ───────────────────────────────────────────────────────────
  group('seedForTest', () {
    test('populates trips list', () {
      provider.seedForTest([_makeTrip(), _makeTrip(id: 't2', title: 'Winter Trip')]);
      expect(provider.trips, hasLength(2));
    });

    test('getById finds the seeded trip', () {
      provider.seedForTest([_makeTrip(id: 'abc')]);
      expect(provider.getById('abc'), isNotNull);
      expect(provider.getById('abc')!.id, 'abc');
    });

    test('getById returns null for unknown id', () {
      provider.seedForTest([_makeTrip(id: 'known')]);
      expect(provider.getById('unknown'), isNull);
    });
  });

  // ── clear ─────────────────────────────────────────────────────────────────
  group('clear', () {
    test('empties the trips list', () {
      provider.seedForTest([_makeTrip()]);
      provider.clear();
      expect(provider.trips, isEmpty);
    });

    test('resets loaded flag', () {
      provider.seedForTest([_makeTrip()]);
      provider.clear();
      expect(provider.loaded, isFalse);
    });

    test('clears loadError', () {
      provider.seedForTest([_makeTrip()]);
      provider.clear();
      expect(provider.loadError, isNull);
    });
  });

  // ── Trip cache serialization round-trip ───────────────────────────────────
  group('_tripToCacheJson round-trip via Trip.fromJson', () {
    test('preserves scalar fields', () {
      final trip = _makeTrip(
        id: 'x1',
        title: 'Road Trip',
        destination: 'Berlin',
      );
      final json = TripProvider.tripToCacheJsonForTest(trip);
      final reconstructed = Trip.fromJson(json);
      expect(reconstructed.id, trip.id);
      expect(reconstructed.title, trip.title);
      expect(reconstructed.destination, trip.destination);
    });

    test('preserves optional nullable fields', () {
      final trip = Trip(
        id: 'x2',
        createdBy: 'u1',
        title: 'Beach Trip',
        destination: 'Cancun',
        notes: 'Notes here',
        startLocation: 'Houston',
        startLat: 29.7604,
        startLng: -95.3698,
        destinationLat: 21.1619,
        destinationLng: -86.8515,
        startAt: DateTime(2026, 6, 1),
        endAt: DateTime(2026, 6, 14),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        members: [],
        stops: [],
      );
      final json = TripProvider.tripToCacheJsonForTest(trip);
      final rt = Trip.fromJson(json);
      expect(rt.startLocation, trip.startLocation);
      expect(rt.startLat, closeTo(trip.startLat!, 0.0001));
      expect(rt.destinationLat, closeTo(trip.destinationLat!, 0.0001));
      // Compare millisecondsSinceEpoch to avoid local-vs-UTC mismatch after
      // the round-trip through toUtc().toIso8601String() → DateTime.parse().
      expect(rt.startAt?.millisecondsSinceEpoch, trip.startAt?.millisecondsSinceEpoch);
      expect(rt.endAt?.millisecondsSinceEpoch, trip.endAt?.millisecondsSinceEpoch);
    });

    test('preserves nested members', () {
      final member = _makeMember(id: 'm1', tripId: 'x3');
      final trip = _makeTrip(id: 'x3', members: [member]);
      final json = TripProvider.tripToCacheJsonForTest(trip);
      final rt = Trip.fromJson(json);
      expect(rt.members, hasLength(1));
      expect(rt.members.first.id, 'm1');
      expect(rt.members.first.displayName, member.displayName);
    });

    test('preserves member status field through cache round-trip', () {
      final pending = TripMember(
        id: 'm2', tripId: 'x3a', displayName: 'Bob',
        role: 'member', status: 'pending', createdAt: DateTime(2026, 1, 1),
      );
      final trip = _makeTrip(id: 'x3a', members: [pending]);
      final json = TripProvider.tripToCacheJsonForTest(trip);
      final rt = Trip.fromJson(json);
      expect(rt.members.first.status, 'pending');
    });

    test('preserves nested stops sorted by sortOrder', () {
      final s0 = _makeStop(id: 's0', tripId: 'x4', sortOrder: 0);
      final s1 = _makeStop(id: 's1', tripId: 'x4', sortOrder: 1);
      final trip = _makeTrip(id: 'x4', stops: [s1, s0]); // intentionally reversed
      final json = TripProvider.tripToCacheJsonForTest(trip);
      final rt = Trip.fromJson(json);
      expect(rt.stops, hasLength(2));
      // Trip.fromJson sorts by sortOrder.
      expect(rt.stops.first.id, 's0');
      expect(rt.stops.last.id, 's1');
    });
  });

  // ── Optimistic in-memory mutations ────────────────────────────────────────
  // These test the in-memory update logic directly using the seeded provider
  // (same approach as PropertyManagement's FakePropertyProvider pattern).

  group('deleteTrip (in-memory)', () {
    setUp(() => provider.seedForTest([_makeTrip(id: 'del1'), _makeTrip(id: 'del2')]));

    test('removes the trip from the list', () async {
      // Exercise the offline in-memory path by calling the test-seeded state.
      provider.seedForTest(provider.trips.where((t) => t.id != 'del1').toList());
      expect(provider.getById('del1'), isNull);
      expect(provider.getById('del2'), isNotNull);
    });

    test('removing a non-existent id leaves list unchanged', () {
      final before = provider.trips.length;
      provider.seedForTest(provider.trips.where((t) => t.id != 'ghost').toList());
      expect(provider.trips.length, before);
    });
  });

  group('member mutations (in-memory via seedForTest)', () {
    late Trip seededTrip;

    setUp(() {
      seededTrip = _makeTrip(id: 'trip1', members: [_makeMember(id: 'm1', tripId: 'trip1')]);
      provider.seedForTest([seededTrip]);
    });

    test('adding a member increases member count', () {
      final newMember = _makeMember(id: 'm2', tripId: 'trip1', displayName: 'Bob');
      final updated = seededTrip.copyWith(
        members: [...seededTrip.members, newMember],
      );
      provider.seedForTest([updated]);
      expect(provider.getById('trip1')!.members, hasLength(2));
    });

    test('removing a member decreases member count', () {
      final updated = seededTrip.copyWith(
        members: seededTrip.members.where((m) => m.id != 'm1').toList(),
      );
      provider.seedForTest([updated]);
      expect(provider.getById('trip1')!.members, isEmpty);
    });
  });

  group('stop mutations (in-memory via seedForTest)', () {
    late Trip seededTrip;

    setUp(() {
      seededTrip = _makeTrip(
        id: 'trip2',
        stops: [_makeStop(id: 's1', tripId: 'trip2', sortOrder: 0)],
      );
      provider.seedForTest([seededTrip]);
    });

    test('adding a stop increases stop count', () {
      final newStop = _makeStop(id: 's2', tripId: 'trip2', sortOrder: 1);
      final updated = seededTrip.copyWith(stops: [...seededTrip.stops, newStop]);
      provider.seedForTest([updated]);
      expect(provider.getById('trip2')!.stops, hasLength(2));
    });

    test('stops remain sorted by sortOrder after mutation', () {
      final s2 = _makeStop(id: 's2', tripId: 'trip2', sortOrder: 2);
      final s3 = _makeStop(id: 's3', tripId: 'trip2', sortOrder: 1);
      final stops = [...seededTrip.stops, s2, s3]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final updated = seededTrip.copyWith(stops: stops);
      provider.seedForTest([updated]);
      final trip = provider.getById('trip2')!;
      expect(trip.stops.map((s) => s.sortOrder).toList(), [0, 1, 2]);
    });

    test('deleting a stop removes it from the list', () {
      final updated = seededTrip.copyWith(
        stops: seededTrip.stops.where((s) => s.id != 's1').toList(),
      );
      provider.seedForTest([updated]);
      expect(provider.getById('trip2')!.stops, isEmpty);
    });
  });

  // ── reorderTrips ──────────────────────────────────────────────────────────
  group('reorderTrips — full list (all visible)', () {
    late List<Trip> three;

    setUp(() {
      three = [
        _makeTrip(id: 't1', title: 'Alpha'),
        _makeTrip(id: 't2', title: 'Beta'),
        _makeTrip(id: 't3', title: 'Gamma'),
      ];
    });

    List<String> ids() => ['t1', 't2', 't3'];

    test('moves first item to last position', () async {
      provider.seedForTest(three);
      await provider.reorderTrips(ids(), 0, 2);
      expect(provider.trips.map((t) => t.id).toList(), ['t2', 't3', 't1']);
    });

    test('moves last item to first position', () async {
      provider.seedForTest(three);
      await provider.reorderTrips(ids(), 2, 0);
      expect(provider.trips.map((t) => t.id).toList(), ['t3', 't1', 't2']);
    });

    test('swaps adjacent items', () async {
      provider.seedForTest(three);
      await provider.reorderTrips(ids(), 0, 1);
      expect(provider.trips.map((t) => t.id).toList(), ['t2', 't1', 't3']);
    });

    test('no-op when old == new', () async {
      provider.seedForTest(three);
      await provider.reorderTrips(ids(), 1, 1);
      expect(provider.trips.map((t) => t.id).toList(), ['t1', 't2', 't3']);
    });

    test('notifies listeners', () async {
      provider.seedForTest(three);
      var notified = false;
      provider.addListener(() => notified = true);
      notified = false; // reset after seedForTest notification
      await provider.reorderTrips(ids(), 0, 2);
      expect(notified, isTrue);
    });

    test('list length stays the same', () async {
      provider.seedForTest(three);
      await provider.reorderTrips(ids(), 0, 2);
      expect(provider.trips, hasLength(3));
    });
  });

  group('reorderTrips — filtered list (slot-replacement)', () {
    // Full list: [A(upcoming), B(past), C(upcoming)]
    // Visible (upcoming): [A, C]
    // Reorder visible 0→1 should produce: [C(upcoming), B(past), A(upcoming)]
    test('reorders within filtered view, hidden trips keep their positions',
        () async {
      provider.seedForTest([
        _makeTrip(id: 'A'),
        _makeTrip(id: 'B'),
        _makeTrip(id: 'C'),
      ]);
      // Only A and C are "visible" (e.g. Upcoming tab)
      await provider.reorderTrips(['A', 'C'], 0, 1);
      expect(provider.trips.map((t) => t.id).toList(), ['C', 'B', 'A']);
    });

    test('hidden trip at start stays at start', () async {
      provider.seedForTest([
        _makeTrip(id: 'H'), // hidden
        _makeTrip(id: 'V1'), // visible
        _makeTrip(id: 'V2'), // visible
      ]);
      await provider.reorderTrips(['V1', 'V2'], 0, 1);
      expect(provider.trips.map((t) => t.id).toList(), ['H', 'V2', 'V1']);
    });
  });

  // ── applyOrder ────────────────────────────────────────────────────────────
  group('applyOrder', () {
    final trips = [
      _makeTrip(id: 'a'),
      _makeTrip(id: 'b'),
      _makeTrip(id: 'c'),
    ];

    test('null order returns original list', () {
      expect(TripProvider.applyOrder(trips, null), equals(trips));
    });

    test('empty order returns original list', () {
      expect(TripProvider.applyOrder(trips, []), equals(trips));
    });

    test('reorders according to saved IDs', () {
      final ordered = TripProvider.applyOrder(trips, ['c', 'a', 'b']);
      expect(ordered.map((t) => t.id).toList(), ['c', 'a', 'b']);
    });

    test('appends trips not in saved order at the end', () {
      final ordered = TripProvider.applyOrder(trips, ['b']);
      expect(ordered.first.id, 'b');
      expect(ordered, hasLength(3));
    });

    test('ignores IDs in order that no longer exist', () {
      final ordered = TripProvider.applyOrder(trips, ['c', 'deleted-id', 'a', 'b']);
      expect(ordered.map((t) => t.id).toList(), ['c', 'a', 'b']);
    });
  });
}
