import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for Melodrift
///
/// SETUP INSTRUCTIONS:
/// 1. Create Firebase project at https://console.firebase.google.com/
/// 2. Register Android app with package name: com.melodrift.dev
/// 3. Download google-services.json from Firebase Console
/// 4. Place at: android/app/google-services.json
/// 5. Get SHA-1: keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey
/// 6. Update the values below from google-services.json
///
/// For local development without Firebase:
/// - Use FOSS flavors (devFoss/prodFoss)
/// - Firebase is optional and gracefully fails over
///
/// Android values are sourced from android/app/google-services.json
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'YOUR_WEB_API_KEY',
        appId: 'YOUR_WEB_APP_ID',
        messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
        projectId: 'YOUR_FIREBASE_PROJECT_ID',
        authDomain: 'YOUR_FIREBASE_PROJECT_ID.firebaseapp.com',
        databaseURL: 'https://YOUR_FIREBASE_PROJECT_ID-default-rtdb.firebaseio.com',
        storageBucket: 'YOUR_FIREBASE_PROJECT_ID.firebasestorage.app',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: 'YOUR_ANDROID_API_KEY',
          appId: 'YOUR_ANDROID_APP_ID',
          messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
          projectId: 'YOUR_FIREBASE_PROJECT_ID',
          databaseURL: 'https://YOUR_FIREBASE_PROJECT_ID-default-rtdb.firebaseio.com',
          storageBucket: 'YOUR_FIREBASE_PROJECT_ID.firebasestorage.app',
        );
      case TargetPlatform.iOS:
        return const FirebaseOptions(
          apiKey: 'YOUR_IOS_API_KEY',
          appId: 'YOUR_IOS_APP_ID',
          messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
          projectId: 'YOUR_FIREBASE_PROJECT_ID',
          databaseURL: 'https://YOUR_FIREBASE_PROJECT_ID-default-rtdb.firebaseio.com',
          storageBucket: 'YOUR_FIREBASE_PROJECT_ID.firebasestorage.app',
          iosBundleId: 'com.melodrift',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
}
