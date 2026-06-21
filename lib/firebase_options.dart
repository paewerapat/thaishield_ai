// GENERATED FILE — do not edit manually.
// Run: flutterfire configure
// to regenerate this file with your Firebase project credentials.
//
// Steps:
//   dart pub global activate flutterfire_cli
//   npm install -g firebase-tools
//   firebase login
//   flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS:     return ios;
      default:
        throw UnsupportedError('DefaultFirebaseOptions not configured for this platform.');
    }
  }

  // TODO: Replace with real values from `flutterfire configure`

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDWw6C1hHSmuATc_zC6FP545J1gqK36UQE',
    appId: '1:479467305669:android:9dfcd44c0da33b7d70ceac',
    messagingSenderId: '479467305669',
    projectId: 'thaishield-ai-790eb',
    storageBucket: 'thaishield-ai-790eb.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAizR99SKJVuWN_a5xprISN6P093U5ui1Y',
    appId: '1:479467305669:ios:c827becdb65c72ff70ceac',
    messagingSenderId: '479467305669',
    projectId: 'thaishield-ai-790eb',
    storageBucket: 'thaishield-ai-790eb.firebasestorage.app',
    iosBundleId: 'com.thaishieldai.app',
  );
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'YOUR_WEB_API_KEY',
    appId:             'YOUR_WEB_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId:         'YOUR_PROJECT_ID',
    storageBucket:     'YOUR_PROJECT_ID.appspot.com',
    authDomain:        'YOUR_PROJECT_ID.firebaseapp.com',
  );
}
