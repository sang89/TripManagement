// Web-only Google Places implementation using the Places API (New).
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'trip_places_service.dart';

// ─── Script injection ─────────────────────────────────────────────────────────

Completer<void>? _mapsReady;

void preloadWeb(String apiKey) => _ensureMapsLoaded(apiKey);

Future<void> _ensureMapsLoaded(String apiKey) {
  if (_mapsReady != null) return _mapsReady!.future;
  _mapsReady = Completer<void>();

  final document = globalContext['document'] as JSObject;
  final head = document['head'] as JSObject;

  final helpers = document.callMethod<JSObject>(
      'createElement'.toJS, 'script'.toJS);
  helpers['textContent'] = r'''
window.__tmGetPredictions = async function(input) {
  const { AutocompleteSuggestion } =
      await google.maps.importLibrary('places');
  const response =
      await AutocompleteSuggestion.fetchAutocompleteSuggestions({ input: input });
  return (response.suggestions || []).map(function(s) {
    var p = s.placePrediction;
    return {
      place_id:       p.placeId,
      description:    p.text          ? p.text.text          : '',
      main_text:      p.mainText      ? p.mainText.text      : '',
      secondary_text: p.secondaryText ? p.secondaryText.text : '',
    };
  });
};

window.__tmGetDetails = async function(placeId) {
  const { Place } = await google.maps.importLibrary('places');
  var place = new Place({ id: placeId });
  await place.fetchFields({ fields: ['formattedAddress', 'location', 'displayName'] });
  return {
    description: place.formattedAddress || (place.displayName ? place.displayName.text : '') || '',
    lat: place.location ? place.location.lat() : null,
    lng: place.location ? place.location.lng() : null,
  };
};
'''.toJS;
  head.callMethod<JSAny?>('appendChild'.toJS, helpers);

  globalContext['__tmGMapsReady'] = (() {
    if (!_mapsReady!.isCompleted) _mapsReady!.complete();
  }).toJS;

  final sdk = document.callMethod<JSObject>(
      'createElement'.toJS, 'script'.toJS);
  sdk['src'] = 'https://maps.googleapis.com/maps/api/js'
      '?key=$apiKey'
      '&v=weekly'
      '&loading=async'
      '&callback=__tmGMapsReady'.toJS;

  void onError(JSAny? _) {
    if (!_mapsReady!.isCompleted) {
      _mapsReady!.completeError('Failed to load Google Maps SDK.');
    }
  }
  sdk['onerror'] = onError.toJS;
  head.callMethod<JSAny?>('appendChild'.toJS, sdk);

  return _mapsReady!.future;
}

// ─── Public API ───────────────────────────────────────────────────────────────

Future<SuggestionsResult> fetchSuggestionsWeb(
    String input, String apiKey) async {
  try {
    await _ensureMapsLoaded(apiKey);

    final promise = globalContext.callMethod<JSPromise<JSAny>>(
        '__tmGetPredictions'.toJS, input.toJS);
    final raw = await promise.toDart;

    final arr = raw as JSArray<JSObject>;
    final len = ((arr as JSObject)['length'] as JSNumber).toDartInt;
    final predictions = <PlacePrediction>[];

    for (var i = 0; i < len; i++) {
      final item = arr[i];
      final placeId = (item['place_id'] as JSString).toDart;
      final description = (item['description'] as JSString).toDart;
      final mainText = (item['main_text'] as JSString?)?.toDart ?? description;
      final secondaryText = (item['secondary_text'] as JSString?)?.toDart ?? '';
      predictions.add(PlacePrediction(
        placeId: placeId,
        description: description,
        mainText: mainText,
        secondaryText: secondaryText,
      ));
    }

    return SuggestionsResult(predictions: predictions);
  } catch (e) {
    final msg = e.toString();
    if (msg.contains('ZERO_RESULTS')) return const SuggestionsResult();
    return SuggestionsResult(errorMessage: 'Places error: $msg');
  }
}

Future<TripPlaceDetails?> fetchDetailsWeb(
    String placeId, String apiKey, String fallback) async {
  try {
    await _ensureMapsLoaded(apiKey);

    final promise = globalContext.callMethod<JSPromise<JSAny>>(
        '__tmGetDetails'.toJS, placeId.toJS);
    final raw = await promise.toDart;

    final obj = raw as JSObject;
    final description =
        (obj['description'] as JSString?)?.toDart ?? fallback;
    final latJs = obj['lat'];
    final lngJs = obj['lng'];
    final lat = latJs.isA<JSNumber>() ? (latJs as JSNumber).toDartDouble : null;
    final lng = lngJs.isA<JSNumber>() ? (lngJs as JSNumber).toDartDouble : null;

    return TripPlaceDetails(description: description, lat: lat, lng: lng);
  } catch (e) {
    return null;
  }
}
