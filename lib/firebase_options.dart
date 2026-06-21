import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'mock-api-key-web',
        appId: 'mock-app-id-web',
        messagingSenderId: 'mock-sender-id',
        projectId: 'mock-project-id',
        databaseURL: 'https://mock-project-id-default-rtdb.firebaseio.com',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: 'mock-api-key-android',
          appId: 'mock-app-id-android',
          messagingSenderId: 'mock-sender-id',
          projectId: 'mock-project-id',
          databaseURL: 'https://mock-project-id-default-rtdb.firebaseio.com',
        );
      case TargetPlatform.iOS:
        return const FirebaseOptions(
          apiKey: 'mock-api-key-ios',
          appId: 'mock-app-id-ios',
          messagingSenderId: 'mock-sender-id',
          projectId: 'mock-project-id',
          databaseURL: 'https://mock-project-id-default-rtdb.firebaseio.com',
          iosBundleId: 'com.melodrift',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
}
