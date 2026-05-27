import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/services/directions_service.dart';

void main() {
  group('DirectionsService._decodePolyline', () {
    // Access the private decoder via a thin public wrapper exposed only in tests.
    // Since _decodePolyline is private we test it indirectly through the known
    // encoded string for a well-documented example from Google's documentation:
    //   "_p~iF~ps|U_ulLnnqC_mqNvxq`@"  →  (38.5,-120.2), (40.7,-120.95), (43.252,-126.453)
    test('decodes Google documented example', () {
      final points =
          DirectionsService.decodePolylineForTest('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(points, hasLength(3));
      expect(points[0].latitude, closeTo(38.5, 0.00001));
      expect(points[0].longitude, closeTo(-120.2, 0.00001));
      expect(points[1].latitude, closeTo(40.7, 0.00001));
      expect(points[1].longitude, closeTo(-120.95, 0.00001));
      expect(points[2].latitude, closeTo(43.252, 0.00001));
      expect(points[2].longitude, closeTo(-126.453, 0.00001));
    });

    test('returns empty list for empty string', () {
      final points = DirectionsService.decodePolylineForTest('');
      expect(points, isEmpty);
    });
  });
}
