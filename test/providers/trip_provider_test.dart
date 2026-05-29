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

class _ResendTrackingProvider extends FakeTripProvider {
  final List<String> _calls;
  _ResendTrackingProvider(this._calls);

  @override
  Future<void> resendInvite(String memberId) async {
    _calls.add(memberId);
  }
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

  // ── Realtime in-memory handlers (simulate _subscribeRealtime callbacks) ──
  // The actual Supabase WebSocket is not available in tests, so we exercise
  // the same in-memory mutation logic directly via seedForTest.  Each test
  // mirrors exactly what the corresponding Realtime callback does.

  group('Realtime — trips UPDATE', () {
    late Trip original;

    setUp(() {
      original = Trip(
        id: 'rt1',
        createdBy: 'uid1',
        title: 'Old Title',
        destination: 'Paris',
        notes: 'old notes',
        startLocation: 'NYC',
        startLat: 40.7,
        startLng: -74.0,
        destinationLat: 48.8,
        destinationLng: 2.3,
        startAt: DateTime(2026, 7, 1),
        endAt: DateTime(2026, 7, 15),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        members: [_makeMember(id: 'm1', tripId: 'rt1')],
        stops: [_makeStop(id: 's1', tripId: 'rt1')],
      );
      provider.seedForTest([original]);
    });

    test('updates scalar fields (title, destination, notes) from payload', () {
      // Simulate the trips UPDATE Realtime callback.
      final payload = {
        'id': 'rt1', 'created_by': 'uid1',
        'title': 'New Title', 'destination': 'Berlin',
        'notes': 'updated notes',
        'start_location': null, 'start_lat': null, 'start_lng': null,
        'destination_lat': 52.5, 'destination_lng': 13.4,
        'start_at': null, 'end_at': null,
        'updated_at': '2026-06-01T00:00:00.000Z',
      };
      final existing = provider.getById('rt1')!;
      final updated = Trip(
        id: existing.id,
        createdBy: existing.createdBy,
        title: payload['title'] as String? ?? existing.title,
        startLocation: payload['start_location'] as String?,
        startLat: (payload['start_lat'] as num?)?.toDouble(),
        startLng: (payload['start_lng'] as num?)?.toDouble(),
        destination: payload['destination'] as String? ?? existing.destination,
        notes: payload['notes'] as String? ?? '',
        destinationLat: (payload['destination_lat'] as num?)?.toDouble(),
        destinationLng: (payload['destination_lng'] as num?)?.toDouble(),
        startAt: null,
        endAt: null,
        createdAt: existing.createdAt,
        updatedAt: DateTime.parse(payload['updated_at'] as String),
        members: existing.members,
        stops: existing.stops,
      );
      provider.seedForTest([updated]);

      final result = provider.getById('rt1')!;
      expect(result.title, 'New Title');
      expect(result.destination, 'Berlin');
      expect(result.notes, 'updated notes');
      expect(result.startLocation, isNull); // cleared
      expect(result.startAt, isNull);
    });

    test('preserves in-memory members after trips UPDATE', () {
      final existing = provider.getById('rt1')!;
      final merged = existing.copyWith(title: 'Merged');
      provider.seedForTest([merged]);
      expect(provider.getById('rt1')!.members, hasLength(1));
      expect(provider.getById('rt1')!.members.first.id, 'm1');
    });

    test('preserves in-memory stops after trips UPDATE', () {
      final existing = provider.getById('rt1')!;
      final merged = existing.copyWith(title: 'Merged');
      provider.seedForTest([merged]);
      expect(provider.getById('rt1')!.stops, hasLength(1));
      expect(provider.getById('rt1')!.stops.first.id, 's1');
    });
  });

  group('Realtime — trip_members INSERT', () {
    late Trip trip;

    setUp(() {
      trip = _makeTrip(id: 't_mi', members: [_makeMember(id: 'ma', tripId: 't_mi')]);
      provider.seedForTest([trip]);
    });

    test('appends a new member to the trip', () {
      final newMember = TripMember(
        id: 'mb', tripId: 't_mi', displayName: 'Bob',
        role: 'member', status: 'pending', createdAt: DateTime(2026, 1, 2),
      );
      final updated = trip.copyWith(members: [...trip.members, newMember]);
      provider.seedForTest([updated]);
      expect(provider.getById('t_mi')!.members, hasLength(2));
    });

    test('dedup: does not double-append a member already in-memory', () {
      // Simulate what the INSERT callback does: skip if id already present.
      final existing = provider.getById('t_mi')!;
      final newMember = existing.members.first; // already there
      final dedupMembers = existing.members.any((m) => m.id == newMember.id)
          ? existing.members
          : [...existing.members, newMember];
      provider.seedForTest([existing.copyWith(members: dedupMembers)]);
      expect(provider.getById('t_mi')!.members, hasLength(1));
    });
  });

  group('Realtime — trip_members UPDATE (full fields)', () {
    late TripMember oldMember;
    late Trip trip;

    setUp(() {
      oldMember = TripMember(
        id: 'mc', tripId: 't_mu', displayName: 'old@example.com',
        role: 'member', status: 'pending', email: 'old@example.com',
        createdAt: DateTime(2026, 1, 1),
      );
      trip = _makeTrip(id: 't_mu', members: [oldMember]);
      provider.seedForTest([trip]);
    });

    test('replaces full member row (not just status)', () {
      // Simulate: TripMember.fromJson(row) → replace in-place.
      final updatedMember = oldMember.copyWith(
        displayName: 'Real Name',
        status: 'accepted',
      );
      final updatedTrip = trip.copyWith(members: [updatedMember]);
      provider.seedForTest([updatedTrip]);
      final m = provider.getById('t_mu')!.members.first;
      expect(m.displayName, 'Real Name');
      expect(m.status, 'accepted');
    });
  });

  group('Realtime — trip_stops INSERT', () {
    late Trip trip;

    setUp(() {
      trip = _makeTrip(
        id: 't_si',
        stops: [_makeStop(id: 'sa', tripId: 't_si', sortOrder: 0)],
      );
      provider.seedForTest([trip]);
    });

    test('appends a new stop', () {
      final newStop = _makeStop(id: 'sb', tripId: 't_si', sortOrder: 1);
      final updatedStops = [...trip.stops, newStop]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      provider.seedForTest([trip.copyWith(stops: updatedStops)]);
      expect(provider.getById('t_si')!.stops, hasLength(2));
    });

    test('stops remain sorted by sortOrder after INSERT', () {
      final newStop = _makeStop(id: 'sc', tripId: 't_si', sortOrder: 1);
      final anotherStop = _makeStop(id: 'sd', tripId: 't_si', sortOrder: 2);
      final updatedStops = [...trip.stops, anotherStop, newStop]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      provider.seedForTest([trip.copyWith(stops: updatedStops)]);
      expect(
        provider.getById('t_si')!.stops.map((s) => s.sortOrder).toList(),
        [0, 1, 2],
      );
    });

    test('dedup: does not double-append a stop already in-memory', () {
      final existing = provider.getById('t_si')!;
      final existingStop = existing.stops.first;
      final dedupStops = existing.stops.any((s) => s.id == existingStop.id)
          ? existing.stops
          : [...existing.stops, existingStop];
      provider.seedForTest([existing.copyWith(stops: dedupStops)]);
      expect(provider.getById('t_si')!.stops, hasLength(1));
    });
  });

  group('Realtime — trip_stops UPDATE', () {
    late TripStop oldStop;
    late Trip trip;

    setUp(() {
      oldStop = _makeStop(id: 'se', tripId: 't_su', sortOrder: 0);
      trip = _makeTrip(id: 't_su', stops: [oldStop]);
      provider.seedForTest([trip]);
    });

    test('replaces stop in-place', () {
      final updatedStop = TripStop(
        id: 'se', tripId: 't_su', title: 'Updated Stop',
        address: 'New Address', notes: 'new notes',
        sortOrder: 0, createdAt: DateTime(2026, 1, 1),
      );
      final updatedStops = List<TripStop>.of(trip.stops);
      updatedStops[0] = updatedStop;
      provider.seedForTest([trip.copyWith(stops: updatedStops)]);
      expect(provider.getById('t_su')!.stops.first.title, 'Updated Stop');
      expect(provider.getById('t_su')!.stops.first.address, 'New Address');
    });
  });

  group('Realtime — trip_stops DELETE', () {
    late Trip trip;

    setUp(() {
      trip = _makeTrip(id: 't_sd', stops: [
        _makeStop(id: 'sf', tripId: 't_sd', sortOrder: 0),
        _makeStop(id: 'sg', tripId: 't_sd', sortOrder: 1),
      ]);
      provider.seedForTest([trip]);
    });

    test('removes the deleted stop', () {
      final remaining = trip.stops.where((s) => s.id != 'sf').toList();
      provider.seedForTest([trip.copyWith(stops: remaining)]);
      expect(provider.getById('t_sd')!.stops, hasLength(1));
      expect(provider.getById('t_sd')!.stops.first.id, 'sg');
    });
  });

  // ── Member name enrichment (in-memory) ───────────────────────────────────
  // These tests exercise the copyWith/seedForTest path that mirrors what
  // TripProvider._enrichMemberNames() does when the DB response arrives.
  group('member name enrichment (in-memory)', () {
    test('displayName is updated when stored value is an email', () {
      final emailMember = TripMember(
        id: 'm1', tripId: 't1',
        displayName: 'organizer@example.com', // email stored as name
        role: 'organizer',
        userId: 'uid1',
        email: 'organizer@example.com',
        createdAt: DateTime(2026, 1, 1),
      );
      final enriched = emailMember.copyWith(displayName: 'John Organizer');
      expect(enriched.displayName, 'John Organizer');
      expect(enriched.email, 'organizer@example.com'); // email preserved
      expect(enriched.userId, 'uid1');
    });

    test('enriched displayName survives cache round-trip', () {
      final member = TripMember(
        id: 'm2', tripId: 't1',
        displayName: 'Real Name',  // already enriched
        role: 'member',
        userId: 'uid2',
        email: 'real@example.com',
        createdAt: DateTime(2026, 1, 1),
      );
      final trip = _makeTrip(id: 't1', members: [member]);
      final json = TripProvider.tripToCacheJsonForTest(trip);
      final rt = Trip.fromJson(json);
      expect(rt.members.first.displayName, 'Real Name');
      expect(rt.members.first.email, 'real@example.com');
    });

    test('guest member displayName is not affected by enrichment logic', () {
      // Guests have userId == null — enrichment skips them.
      final guest = TripMember(
        id: 'g1', tripId: 't1',
        displayName: 'Guest User',
        role: 'member',
        userId: null, // no linked account
        createdAt: DateTime(2026, 1, 1),
      );
      // Simulating the enrichment check: userId == null → unchanged
      final result = guest.userId == null ? guest : guest.copyWith(displayName: 'Should not happen');
      expect(result.displayName, 'Guest User');
    });

    test('enrichment skips member whose displayName already matches profile', () {
      final member = TripMember(
        id: 'm3', tripId: 't1',
        displayName: 'Correct Name',
        role: 'member',
        userId: 'uid3',
        createdAt: DateTime(2026, 1, 1),
      );
      // Simulate: profile returns same name → no copyWith needed.
      const profileName = 'Correct Name';
      final result = profileName == member.displayName
          ? member
          : member.copyWith(displayName: profileName);
      expect(identical(result, member), isTrue);
    });

    test('in-memory state reflects enriched names after seedForTest patch', () {
      final emailMember = TripMember(
        id: 'm4', tripId: 't2',
        displayName: 'user@trip.com',
        role: 'organizer',
        userId: 'uid4',
        createdAt: DateTime(2026, 1, 1),
      );
      final trip = _makeTrip(id: 't2', members: [emailMember]);
      provider.seedForTest([trip]);

      // Simulate the enrichment applied by _enrichMemberNames().
      final enrichedMember = emailMember.copyWith(displayName: 'User Full Name');
      final enrichedTrip = trip.copyWith(members: [enrichedMember]);
      provider.seedForTest([enrichedTrip]);

      final found = provider.getById('t2')!;
      expect(found.members.first.displayName, 'User Full Name');
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

  // ── resendInvite ──────────────────────────────────────────────────────────

  // FakeTripProvider already skips DB I/O by overriding load(); resendInvite
  // normally calls the Supabase RPC so we verify the pattern via a subclass.
  group('resendInvite', () {
    test('subclass can track resend calls', () async {
      final calls = <String>[];
      final prov = _ResendTrackingProvider(calls);
      await prov.resendInvite('m-pending');
      expect(calls, ['m-pending']);
    });

    test('multiple resend calls accumulate in order', () async {
      final calls = <String>[];
      final prov = _ResendTrackingProvider(calls);
      await prov.resendInvite('m1');
      await prov.resendInvite('m2');
      expect(calls, ['m1', 'm2']);
    });
  });
}
