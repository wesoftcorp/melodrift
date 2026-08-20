import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for Melodrift
/// Sourced from Firebase Project: melodrift-melody
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyBtSpZHU5evdAabbVLvFRfHGNEIIsl8Q3w',
        appId: '1:606758484923:web:8ab9360fc9be9786a7229e',
        messagingSenderId: '606758484923',
        projectId: 'melodrift-melody',
        authDomain: 'melodrift-melody.firebaseapp.com',
        databaseURL: 'https://melodrift-melody-default-rtdb.asia-southeast1.firebasedatabase.app',
        storageBucket: 'melodrift-melody.firebasestorage.app',
        measurementId: 'G-02S70Q5BCG',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: 'AIzaSyC7JuwpzXE0iWuNRhVUB3lIiFII4GuEqPM',
          appId: '1:606758484923:android:c383a7dea8d7f211a7229e',
          messagingSenderId: '606758484923',
          projectId: 'melodrift-melody',
          databaseURL: 'https://melodrift-melody-default-rtdb.asia-southeast1.firebasedatabase.app',
          storageBucket: 'melodrift-melody.firebasestorage.app',
        );
      case TargetPlatform.iOS:
        return const FirebaseOptions(
          apiKey: 'AIzaSyC7JuwpzXE0iWuNRhVUB3lIiFII4GuEqPM',
          appId: '1:606758484923:ios:4310c8d968eb9cb9a7229e',
          messagingSenderId: '606758484923',
          projectId: 'melodrift-melody',
          databaseURL: 'https://melodrift-melody-default-rtdb.asia-southeast1.firebasedatabase.app',
          storageBucket: 'melodrift-melody.firebasestorage.app',
          iosBundleId: 'com.melodrift',
        );
      case TargetPlatform.windows:
        return const FirebaseOptions(
          apiKey: 'AIzaSyBtSpZHU5evdAabbVLvFRfHGNEIIsl8Q3w',
          appId: '1:606758484923:web:8ab9360fc9be9786a7229e',
          messagingSenderId: '606758484923',
          projectId: 'melodrift-melody',
          authDomain: 'melodrift-melody.firebaseapp.com',
          databaseURL: 'https://melodrift-melody-default-rtdb.asia-southeast1.firebasedatabase.app',
          storageBucket: 'melodrift-melody.firebasestorage.app',
          measurementId: 'G-02S70Q5BCG',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
}
