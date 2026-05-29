import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_management/l10n/app_localizations.dart';
import 'package:trip_management/models/trip.dart';
import 'package:trip_management/models/trip_member.dart';
import 'package:trip_management/providers/auth_provider.dart';
import 'package:trip_management/providers/trip_provider.dart';
import 'package:trip_management/screens/trips/trip_detail_screen.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeAuthProvider extends AuthProvider {
  final String? _uid;
  _FakeAuthProvider(this._uid);

  @override
  String? get userId => _uid;
}

class _FakeTripProvider extends TripProvider {
  final Trip _trip;
  final List<String> resendCalls = [];

  _FakeTripProvider(this._trip);

  @override
  Future<void> load() async {}

  @override
  bool get loaded => true;

  @override
  List<Trip> get trips => [_trip];

  @override
  Trip? getById(String id) => id == _trip.id ? _trip : null;

  @override
  Future<void> resendInvite(String memberId) async {
    resendCalls.add(memberId);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

TripMember _member({
  required String id,
  required String tripId,
  required String displayName,
  required String status,
  String role = 'member',
  String? userId,
}) =>
    TripMember(
      id: id,
      tripId: tripId,
      displayName: displayName,
      role: role,
      status: status,
      userId: userId,
      createdAt: DateTime(2026, 1, 1),
    );

Trip _trip({
  required String id,
  required String createdBy,
  required List<TripMember> members,
}) =>
    Trip(
      id: id,
      createdBy: createdBy,
      title: 'Test Trip',
      destination: 'Paris',
      notes: '',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      members: members,
      stops: [],
    );

Widget _buildTestWidget({
  required Trip trip,
  required String currentUserId,
  required _FakeTripProvider tripProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
          create: (_) => _FakeAuthProvider(currentUserId)),
      ChangeNotifierProvider<TripProvider>.value(value: tripProvider),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripDetailScreen(tripId: trip.id),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('TripDetailScreen — resend invite button', () {
    const organizerId = 'org-1';
    const memberId = 'mem-1';
    const pendingMemberId = 'pm-1';
    const tripId = 'trip-1';

    final pendingMember = _member(
      id: pendingMemberId,
      tripId: tripId,
      displayName: 'Bob',
      status: 'pending',
      userId: memberId,
    );

    final organizer = _member(
      id: 'om-1',
      tripId: tripId,
      displayName: 'Alice',
      role: 'organizer',
      status: 'accepted',
      userId: organizerId,
    );

    testWidgets('resend button visible to organizer for pending member',
        (tester) async {
      final trip = _trip(
        id: tripId,
        createdBy: organizerId,
        members: [organizer, pendingMember],
      );
      final provider = _FakeTripProvider(trip);
      await tester.pumpWidget(
          _buildTestWidget(
              trip: trip, currentUserId: organizerId, tripProvider: provider));
      await tester.pumpAndSettle();

      // The Overview tab is the first tab — no need to tap.
      expect(
        find.descendant(
          of: find.byType(TripDetailScreen),
          matching: find.byIcon(Icons.send_outlined),
        ),
        findsOneWidget,
      );
    });

    testWidgets('resend button not visible when current user is NOT organizer/member',
        (tester) async {
      // User is a pending invitee — canInvite = false.
      final trip = _trip(
        id: tripId,
        createdBy: organizerId,
        members: [organizer, pendingMember],
      );
      final provider = _FakeTripProvider(trip);
      // Current user = the pending member themselves (memberId)
      await tester.pumpWidget(
          _buildTestWidget(
              trip: trip, currentUserId: memberId, tripProvider: provider));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.send_outlined), findsNothing);
    });

    testWidgets('resend button not visible for accepted members',
        (tester) async {
      final acceptedMember = _member(
        id: 'am-1',
        tripId: tripId,
        displayName: 'Carol',
        status: 'accepted',
        userId: 'carol-id',
      );
      final trip = _trip(
        id: tripId,
        createdBy: organizerId,
        members: [organizer, acceptedMember],
      );
      final provider = _FakeTripProvider(trip);
      await tester.pumpWidget(
          _buildTestWidget(
              trip: trip, currentUserId: organizerId, tripProvider: provider));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.send_outlined), findsNothing);
    });

    testWidgets('tapping resend button calls resendInvite with correct member id',
        (tester) async {
      final trip = _trip(
        id: tripId,
        createdBy: organizerId,
        members: [organizer, pendingMember],
      );
      final provider = _FakeTripProvider(trip);
      await tester.pumpWidget(
          _buildTestWidget(
              trip: trip, currentUserId: organizerId, tripProvider: provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.send_outlined));
      await tester.pump();

      expect(provider.resendCalls, [pendingMemberId]);
    });

    testWidgets('accepted member (non-organizer) also sees resend button',
        (tester) async {
      const acceptedUserId = 'acc-1';
      final acceptedMember = _member(
        id: 'am-2',
        tripId: tripId,
        displayName: 'Dave',
        status: 'accepted',
        userId: acceptedUserId,
      );
      final trip = _trip(
        id: tripId,
        createdBy: organizerId,
        members: [organizer, acceptedMember, pendingMember],
      );
      final provider = _FakeTripProvider(trip);
      // Current user = accepted member (not organizer)
      await tester.pumpWidget(
          _buildTestWidget(
              trip: trip, currentUserId: acceptedUserId, tripProvider: provider));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.send_outlined), findsOneWidget);
    });
  });
}
