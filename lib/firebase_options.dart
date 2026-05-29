// ⚠️  STUB — replace by running:
//
//   flutterfire configure --project=propertymanagement-e49e3
//
// Prerequisites:
//   1. Register TripManagement in Firebase Console (propertymanagement-e49e3):
//      - Add Android app: package name from android/app/build.gradle
//      - Add iOS app: bundle ID from ios/Runner.xcodeproj
//      - Download google-services.json → android/app/
//      - Download GoogleService-Info.plist → ios/Runner/
//   2. Enable Cloud Messaging API v1 in Firebase Console →
//      Project Settings → Cloud Messaging
//   3. Run: flutterfire configure --project=propertymanagement-e49e3
//      This will overwrite this file with real platform options and
//      add the required native config files.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        // Web / desktop: return the android options as a temporary placeholder.
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD0EYLo-3FWLrp9J436K8JDwiTCEHpisbY',
    appId: '1:824615270003:android:52ffababdcbf7f540adc06',
    messagingSenderId: '824615270003',
    projectId: 'propertymanagement-e49e3',
    storageBucket: 'propertymanagement-e49e3.firebasestorage.app',
  );

  // Replace these placeholder values with the real ones from flutterfire configure.

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCWiBjSYHmGl2QWBVHLDAIV5E7fwll3QIk',
    appId: '1:824615270003:ios:afbc2c3c4dcb21870adc06',
    messagingSenderId: '824615270003',
    projectId: 'propertymanagement-e49e3',
    storageBucket: 'propertymanagement-e49e3.firebasestorage.app',
    iosClientId: '824615270003-5714kre5m6si8t8st5e45aqn0sgi863e.apps.googleusercontent.com',
    iosBundleId: 'com.sang89.tripManagement',
  );

}