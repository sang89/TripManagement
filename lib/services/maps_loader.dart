// Platform-adaptive Google Maps JS loader.
//
// On web: dynamically injects the Maps JS API script tag using the key
// from kGooglePlacesApiKey in api_keys.dart.
// On mobile: no-op (Maps JS is not needed; google_maps_flutter uses the
// native SDK directly).
//
// Usage in main.dart:
//   await injectGoogleMapsScript(); // safe to call on all platforms
export 'maps_loader_stub.dart'
    if (dart.library.js_interop) 'web_maps_loader.dart';
