import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/widgets/trip_map_widget.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

final _pins = [
  const TripMapPin(id: 'a', position: LatLng(48.8566, 2.3522), title: 'Paris', isStart: true),
  const TripMapPin(id: 'b', position: LatLng(51.5074, -0.1278), title: 'London', isDestination: true),
];

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    TripMapWidget.clearCachesForTest();
    TripMapWidget.seedRouteCacheForTest(
      _pins.map((p) => p.position).toList(),
      null,
    );
  });

  group('TripMapWidget', () {
    testWidgets('shows FlutterMap when pins are provided', (tester) async {
      await tester.pumpWidget(_wrap(TripMapWidget(pins: _pins)));
      await tester.pump();
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('shows empty placeholder when pins is empty', (tester) async {
      await tester.pumpWidget(_wrap(const TripMapWidget(pins: [])));
      await tester.pump();
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    });

    testWidgets('compact mode wraps map in fixed height container', (tester) async {
      await tester.pumpWidget(_wrap(TripMapWidget(pins: _pins, compact: true)));
      await tester.pump();
      expect(find.byType(FlutterMap), findsOneWidget);
      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(of: find.byType(FlutterMap), matching: find.byType(SizedBox)).first,
      );
      expect(sizedBox.height, 220);
    });
  });
}
