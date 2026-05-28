#!/usr/bin/env bash
# NOTE: This script is no longer required for local development.
#
# The Google Maps JS API is now loaded dynamically from Dart code in
# lib/services/web_maps_loader.dart. The key is read from
# lib/config/api_keys.dart (git-ignored) at compile time — no key ever
# appears in web/index.html.
#
# Just run:  flutter run -d chrome
#
# For CI/CD: ensure lib/config/api_keys.dart is restored from your secret
# manager before running `flutter build web`.

echo "ℹ  setup_web.sh is no longer needed — the Maps key is injected automatically."
echo "   Just run: flutter run -d chrome"
