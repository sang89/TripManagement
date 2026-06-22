import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trip_management/services/trip_places_service.dart';

void main() {
  group('placesPhotoUrl', () {
    test('points at the places-proxy photo action', () {
      final url = placesPhotoUrl('places/abc/photos/xyz', maxWidth: 200);
      expect(url, contains('/functions/v1/places-proxy'));
      expect(url, contains('action=photo'));
      expect(url, contains('maxWidth=200'));
      expect(url, contains(Uri.encodeComponent('places/abc/photos/xyz')));
    });

    test('never embeds a Google API key or hits Google directly', () {
      final url = placesPhotoUrl('places/abc/photos/xyz').toLowerCase();
      expect(url, isNot(contains('key=')));
      expect(url, isNot(contains('googleapis.com')));
    });

    test('defaults to maxWidth 400', () {
      expect(placesPhotoUrl('places/a/photos/b'), contains('maxWidth=400'));
    });
  });

  group('searchRestaurants', () {
    test('routes through the proxy searchText action, not Google directly',
        () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'places': [
              {
                'id': 'p1',
                'displayName': {'text': 'Sushi Place'},
                'formattedAddress': '1 Main St',
                'rating': 4.5,
                'priceLevel': 'PRICE_LEVEL_MODERATE',
                'photos': [
                  {'name': 'places/p1/photos/a'}
                ],
                'primaryType': 'restaurant',
              }
            ]
          }),
          200,
        );
      });

      final svc = TripPlacesService('test-key', client: client);
      final results = await svc.searchRestaurants('sushi');

      expect(captured.url.path, contains('/functions/v1/places-proxy'));
      expect(captured.url.queryParameters['action'], 'searchText');
      expect(captured.url.host, isNot('places.googleapis.com'));
      // The Google key must never leave the server.
      expect(captured.headers.containsKey('X-Goog-Api-Key'), isFalse);

      expect(results, hasLength(1));
      expect(results.first.name, 'Sushi Place');
      expect(results.first.priceLevel, 2);
      expect(results.first.photoRef, 'places/p1/photos/a');
    });

    test('returns empty list when the proxy reports an error', () async {
      final client =
          MockClient((req) async => http.Response('{"error":"x"}', 400));
      final svc = TripPlacesService('test-key', client: client);
      expect(await svc.searchRestaurants('sushi'), isEmpty);
    });
  });

  group('fetchSuggestions (mobile)', () {
    test('routes through the proxy autocomplete action', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'suggestions': [
              {
                'placePrediction': {
                  'placeId': 'x',
                  'text': {'text': 'Paris'}
                }
              }
            ]
          }),
          200,
        );
      });

      final svc = TripPlacesService('test-key', client: client);
      final res = await svc.fetchSuggestions('par');

      expect(captured.url.queryParameters['action'], 'autocomplete');
      expect(captured.url.host, isNot('places.googleapis.com'));
      expect(res.predictions, hasLength(1));
      expect(res.predictions.first.placeId, 'x');
    });
  });
}
