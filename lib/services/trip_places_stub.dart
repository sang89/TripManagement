// Non-web stub — never called on mobile.
import 'trip_places_service.dart';

void preloadWeb(String apiKey) {}

Future<SuggestionsResult> fetchSuggestionsWeb(
        String input, String apiKey) async =>
    const SuggestionsResult();

Future<TripPlaceDetails?> fetchDetailsWeb(
        String placeId, String apiKey, String fallback) async =>
    null;
