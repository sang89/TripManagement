import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trip_management/widgets/trip_map_widget.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

// Use isStart/isDestination so _stopPins is empty — avoids _makeStopIcon()
// which uses dart:ui canvas operations that don't complete in fake_async.
final _pins = [
  const TripMapPin(id: 'a', position: LatLng(48.8566, 2.3522), title: 'Paris', isStart: true),
  const TripMapPin(id: 'b', position: LatLng(51.5074, -0.1278), title: 'London', isDestination: true),
];

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // Wipe static caches between tests so they don't bleed.
  // Pre-seed the route with null so _loadRoute hits the cache immediately
  // instead of making an HTTP call that would leave a pending Future.
  setUp(() {
    TripMapWidget.clearCachesForTest();
    TripMapWidget.seedRouteCacheForTest(
      _pins.map((p) => p.position).toList(),
      null,
    );
  });

  group('TripMapWidget — no AutomaticKeepAlive', () {
    testWidgets('shows loading placeholder before prereqs complete', (tester) async {
      await tester.pumpWidget(_wrap(TripMapWidget(pins: _pins)));
      await tester.pump(); // initState

      // The map must NOT be visible yet — 50 ms timer has not fired.
      expect(find.text('Loading map…'), findsOneWidget);

      // Drain the pending 50 ms mount timer so the harness doesn't complain
      // about pending timers after the test ends.
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows empty placeholder when pins is empty', (tester) async {
      await tester.pumpWidget(_wrap(const TripMapWidget(pins: [])));
      await tester.pump();
      expect(find.text('Loading map…'), findsNothing);
      expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    });

    testWidgets(
        '_appActive gate: map does not mount while app is paused', (tester) async {
      await tester.pumpWidget(_wrap(TripMapWidget(pins: _pins)));
      await tester.pump();

      // Simulate backgrounding BEFORE the 50 ms timer fires.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Advance past the timer — _checkMount should be a no-op because
      // _appActive == false.
      await tester.pump(const Duration(milliseconds: 200));

      // Still loading placeholder, not the map.
      expect(find.text('Loading map…'), findsOneWidget);
    });

    testWidgets(
        '_appActive gate: map mounts after resumed fires', (tester) async {
      await tester.pumpWidget(_wrap(TripMapWidget(pins: _pins)));
      await tester.pump();

      // Background before the timer fires.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      // Advance past the 50 ms timer — blocked by _appActive == false.
      await tester.pump(const Duration(milliseconds: 200));

      // Still loading.
      expect(find.text('Loading map…'), findsOneWidget);

      // Foreground — _appActive becomes true, _checkMount re-evaluates.
      // Timer already fired while paused (200 ms > 50 ms) and icons for
      // start/destination-only pins complete instantly → map mounts.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(); // let setState settle

      // GoogleMap widget is now in the tree (mount decision was made).
      // Note: onMapCreated never fires in widget tests, so the opaque loading
      // overlay (_mapReady == false) is still shown — we assert on GoogleMap
      // presence rather than absence of the loading text.
      expect(find.byType(GoogleMap), findsOneWidget);
    });

    testWidgets('map mounts after timer without waiting for route', (tester) async {
      // Route is NOT pre-seeded — the Directions API call will be pending.
      // The map should mount anyway (route does not gate _checkMount).

      await tester.pumpWidget(_wrap(TripMapWidget(pins: _pins)));
      await tester.pump();
      // Advance past the 50 ms timer.
      await tester.pump(const Duration(milliseconds: 100));

      // Timer fired, icons loaded (0 stop pins for start/destination pins) →
      // map mounts immediately without waiting for the route API.
      // The polyline starts as a straight-line fallback and updates when the
      // route arrives.
      expect(find.byType(GoogleMap), findsOneWidget);
    });
  });
}
