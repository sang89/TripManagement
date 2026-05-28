// Web-only implementation — imported via maps_loader.dart conditional export.
// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../config/api_keys.dart';

/// Dynamically injects the Google Maps JavaScript API into the page.
///
/// Called once in [main] before [runApp]. The [await] ensures the script
/// is fully loaded — and [window.google.maps] is available — before any
/// map widget is rendered.
///
/// Idempotent: if the script tag is already present (e.g. after a hot restart
/// in development), this is a no-op.
Future<void> injectGoogleMapsScript() async {
  // Already injected — skip.
  if (web.document
          .querySelector('script[src*="maps.googleapis.com/maps/api/js"]') !=
      null) {
    return;
  }

  final completer = Completer<void>();

  final script =
      web.document.createElement('script') as web.HTMLScriptElement;
  script.src =
      'https://maps.googleapis.com/maps/api/js?key=$kGooglePlacesApiKey';

  script.onload = ((web.Event _) {
    completer.complete();
  }).toJS;

  script.onerror = ((web.Event _) {
    completer
        .completeError(Exception('Google Maps JS API failed to load.'));
  }).toJS;

  web.document.head!.appendChild(script);
  await completer.future;
}
