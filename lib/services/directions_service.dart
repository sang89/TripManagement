import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/api_keys.dart';

/// Fetches driving-route polylines from the Google Maps Directions API.
class DirectionsService {
  static const _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Returns decoded [LatLng] points for the driving route through [waypoints]
  /// in order. Returns `null` when the API request fails or the key lacks
  /// Directions API access.
  ///
  /// Always returns `null` on web — the Directions REST API does not send
  /// CORS headers, so browser requests are blocked. The caller falls back to
  /// straight-line display automatically.
  static Future<List<LatLng>?> getRoute(List<LatLng> waypoints) async {
    if (kIsWeb) return null; // Directions REST API blocked by CORS on web.
    if (waypoints.length < 2) return null;

    final origin =
        '${waypoints.first.latitude},${waypoints.first.longitude}';
    final destination =
        '${waypoints.last.latitude},${waypoints.last.longitude}';

    final params = <String, String>{
      'origin': origin,
      'destination': destination,
      'key': kGooglePlacesApiKey,
    };

    if (waypoints.length > 2) {
      final middle = waypoints.sublist(1, waypoints.length - 1);
      params['waypoints'] =
          middle.map((p) => '${p.latitude},${p.longitude}').join('|');
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final encodedPolyline =
          routes[0]['overview_polyline']['points'] as String;
      return _decodePolyline(encodedPolyline);
    } catch (_) {
      return null;
    }
  }

  /// Public entry point for unit tests — delegates to [_decodePolyline].
  @visibleForTesting
  static List<LatLng> decodePolylineForTest(String encoded) =>
      _decodePolyline(encoded);

  /// Decodes a Google-encoded polyline string into a list of [LatLng] points.
  /// Algorithm: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
  static List<LatLng> _decodePolyline(String encoded) {
    final result = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      // Decode latitude delta
      int shift = 0;
      int value = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        value |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lat += (value & 1) != 0 ? ~(value >> 1) : value >> 1;

      // Decode longitude delta
      shift = 0;
      value = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        value |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lng += (value & 1) != 0 ? ~(value >> 1) : value >> 1;

      result.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return result;
  }
}
