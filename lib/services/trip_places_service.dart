import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:http/http.dart' as http;

import 'cache_entry.dart';
import 'trip_places_stub.dart'
    if (dart.library.js_interop) 'trip_places_web.dart' as impl;

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });
}

class TripPlaceDetails {
  final String description;
  final double? lat;
  final double? lng;

  const TripPlaceDetails({
    required this.description,
    this.lat,
    this.lng,
  });
}

class RestaurantDetails {
  final double? rating;
  final int? priceLevel;
  final String? photoRef;

  const RestaurantDetails({this.rating, this.priceLevel, this.photoRef});
}

class RestaurantSuggestion {
  final String placeId;
  final String name;
  final String address;
  final double? rating;
  final int? priceLevel;
  final String? photoRef;

  const RestaurantSuggestion({
    required this.placeId,
    required this.name,
    required this.address,
    this.rating,
    this.priceLevel,
    this.photoRef,
  });
}

class SuggestionsResult {
  final List<PlacePrediction> predictions;
  final String? errorMessage;

  const SuggestionsResult({this.predictions = const [], this.errorMessage});
  bool get hasError => errorMessage != null;
}

class TripPlacesService {
  final String apiKey;
  final http.Client _client;

  @visibleForTesting
  static Duration suggestionsTtl = const Duration(hours: 1);
  final Map<String, CacheEntry<SuggestionsResult>> _suggestionsCache = {};
  final Map<String, TripPlaceDetails> _detailsCache = {};

  TripPlacesService(this.apiKey, {http.Client? client})
      : _client = client ?? http.Client();

  bool get isConfigured =>
      apiKey.isNotEmpty && apiKey != 'YOUR_GOOGLE_PLACES_API_KEY';

  void preload() {
    if (isConfigured && kIsWeb) impl.preloadWeb(apiKey);
  }

  Future<SuggestionsResult> fetchSuggestions(String input) async {
    if (!isConfigured || input.length < 3) return const SuggestionsResult();

    final cacheKey = input.trim().toLowerCase();
    final cached = _suggestionsCache[cacheKey];
    if (cached != null && !cached.isExpired(suggestionsTtl)) return cached.value;

    final result = kIsWeb
        ? await impl.fetchSuggestionsWeb(input, apiKey)
        : await _fetchSuggestionsMobile(input);

    if (!result.hasError) _suggestionsCache[cacheKey] = CacheEntry(result);
    return result;
  }

  Future<SuggestionsResult> _fetchSuggestionsMobile(String input) async {
    try {
      final response = await _client
          .post(
            Uri.parse('https://places.googleapis.com/v1/places:autocomplete'),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
            },
            body: jsonEncode({'input': input, 'languageCode': 'en'}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return SuggestionsResult(
            errorMessage: 'Network error (${response.statusCode}).');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final suggestions = data['suggestions'] as List? ?? [];

      final predictions = suggestions
          .map((s) {
            final pp = (s as Map<String, dynamic>)['placePrediction']
                as Map<String, dynamic>?;
            if (pp == null) return null;
            final placeId = pp['placeId'] as String? ?? '';
            final text =
                (pp['text'] as Map<String, dynamic>?)?['text'] as String? ?? '';
            final structured =
                pp['structuredFormat'] as Map<String, dynamic>? ?? {};
            final mainText =
                (structured['mainText'] as Map<String, dynamic>?)?['text']
                    as String? ??
                    text;
            final secondaryText =
                (structured['secondaryText'] as Map<String, dynamic>?)?['text']
                    as String? ??
                    '';
            return PlacePrediction(
              placeId: placeId,
              description: text,
              mainText: mainText,
              secondaryText: secondaryText,
            );
          })
          .whereType<PlacePrediction>()
          .toList();

      return SuggestionsResult(predictions: predictions);
    } catch (e) {
      return SuggestionsResult(errorMessage: 'Connection error. Check network.');
    }
  }

  Future<TripPlaceDetails?> fetchDetails(String placeId, String fallbackDescription) async {
    if (!isConfigured) return null;

    if (_detailsCache.containsKey(placeId)) return _detailsCache[placeId];

    TripPlaceDetails? details;

    if (kIsWeb) {
      details = await impl.fetchDetailsWeb(placeId, apiKey, fallbackDescription);
    } else {
      try {
        final response = await _client
            .get(
              Uri.parse('https://places.googleapis.com/v1/places/$placeId'),
              headers: {
                'X-Goog-Api-Key': apiKey,
                'X-Goog-FieldMask': 'formattedAddress,location',
              },
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) return null;

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address =
            data['formattedAddress'] as String? ?? fallbackDescription;
        final loc = data['location'] as Map<String, dynamic>?;
        details = TripPlaceDetails(
          description: address,
          lat: (loc?['latitude'] as num?)?.toDouble(),
          lng: (loc?['longitude'] as num?)?.toDouble(),
        );
      } catch (e) {
        return null;
      }
    }

    if (details != null) _detailsCache[placeId] = details;
    return details;
  }

  Future<List<RestaurantSuggestion>> searchRestaurants(
    String query, {
    double? lat,
    double? lng,
  }) async {
    if (!isConfigured || query.trim().isEmpty) return [];
    try {
      final body = <String, dynamic>{
        'textQuery': query.trim(),
        'maxResultCount': 5,
        'includedType': 'restaurant',
      };
      if (lat != null && lng != null) {
        body['locationBias'] = {
          'circle': {
            'center': {'latitude': lat, 'longitude': lng},
            'radius': 3000.0,
          },
        };
      }
      final response = await _client
          .post(
            Uri.parse(
                'https://places.googleapis.com/v1/places:searchText'),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask':
                  'places.id,places.displayName,places.formattedAddress,places.rating,places.priceLevel,places.photos',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final places = data['places'] as List? ?? [];
      return places.map((p) {
        final map = p as Map<String, dynamic>;
        final name =
            (map['displayName'] as Map<String, dynamic>?)?['text'] as String? ??
                '';
        final address = map['formattedAddress'] as String? ?? '';
        final rating = (map['rating'] as num?)?.toDouble();
        final priceLevelStr = map['priceLevel'] as String?;
        final priceLevel = switch (priceLevelStr) {
          'PRICE_LEVEL_INEXPENSIVE' => 1,
          'PRICE_LEVEL_MODERATE' => 2,
          'PRICE_LEVEL_EXPENSIVE' => 3,
          'PRICE_LEVEL_VERY_EXPENSIVE' => 4,
          _ => null,
        };
        final photos = map['photos'] as List?;
        final photoRef = photos != null && photos.isNotEmpty
            ? (photos.first as Map<String, dynamic>)['name'] as String?
            : null;
        return RestaurantSuggestion(
          placeId: map['id'] as String? ?? '',
          name: name,
          address: address,
          rating: rating,
          priceLevel: priceLevel,
          photoRef: photoRef,
        );
      }).where((r) => r.placeId.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  Future<RestaurantDetails?> fetchRestaurantDetails(
      String placeId, String fallbackName) async {
    if (!isConfigured) return null;
    try {
      final response = await _client
          .get(
            Uri.parse('https://places.googleapis.com/v1/places/$placeId'),
            headers: {
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask': 'rating,priceLevel,photos',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rating = (data['rating'] as num?)?.toDouble();
      final priceLevelStr = data['priceLevel'] as String?;
      final priceLevel = switch (priceLevelStr) {
        'PRICE_LEVEL_INEXPENSIVE' => 1,
        'PRICE_LEVEL_MODERATE' => 2,
        'PRICE_LEVEL_EXPENSIVE' => 3,
        'PRICE_LEVEL_VERY_EXPENSIVE' => 4,
        _ => null,
      };
      final photos = data['photos'] as List?;
      final photoRef = photos != null && photos.isNotEmpty
          ? (photos.first as Map<String, dynamic>)['name'] as String?
          : null;
      return RestaurantDetails(
          rating: rating, priceLevel: priceLevel, photoRef: photoRef);
    } catch (_) {
      return null;
    }
  }
}
