import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../flavors.dart';
import '../../core/theme/theme_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthRepositoryImpl(prefs);
});

class AuthRepositoryImpl implements AuthRepository {
  final SharedPreferences _prefs;
  final StreamController<UserModel?> _authStateController = StreamController<UserModel?>.broadcast();
  UserModel? _mockUser;
  bool _isFirebaseInitialized = false;

  AuthRepositoryImpl(this._prefs) {
    _init();
  }

  bool get _useFirebase => _prefs.getBool('use_firebase') ?? false;

  void _init() {
    if (F.isFull && _useFirebase) {
      try {
        FirebaseAuth.instance.authStateChanges().listen((firebaseUser) {
          if (firebaseUser != null) {
            final user = UserModel(
              uid: firebaseUser.uid,
              displayName: firebaseUser.displayName ?? 'Google User',
              email: firebaseUser.email,
              photoUrl: firebaseUser.photoURL,
            );
            _authStateController.add(user);
          } else {
            _authStateController.add(null);
          }
        });
        _isFirebaseInitialized = true;
        return;
      } catch (_) {
        // Fall back to local mock mode
      }
    }
    _authStateController.add(_mockUser);
  }

  @override
  Stream<UserModel?> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser {
    if (F.isFull && _useFirebase && _isFirebaseInitialized) {
      try {
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          return UserModel(
            uid: firebaseUser.uid,
            displayName: firebaseUser.displayName ?? 'Google User',
            email: firebaseUser.email,
            photoUrl: firebaseUser.photoURL,
          );
        }
      } catch (_) {}
    }
    return _mockUser;
  }

  @override
  Future<UserModel?> signInWithGoogle() async {
    if (F.isFull && _useFirebase) {
      try {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        final firebaseUser = userCredential.user;

        if (firebaseUser != null) {
          final user = UserModel(
            uid: firebaseUser.uid,
            displayName: firebaseUser.displayName ?? 'Google User',
            email: firebaseUser.email,
            photoUrl: firebaseUser.photoURL,
          );
          _authStateController.add(user);
          return user;
        }
      } catch (_) {
        // Configuration issues or cancel -> Fallback to Guest
      }
    }

    final guestNum = 1000 + DateTime.now().millisecond % 9000;
    final user = UserModel(
      uid: 'guest_$guestNum',
      displayName: 'Guest User $guestNum',
      email: 'guest_$guestNum@melodrift.local',
      photoUrl: '',
    );
    _mockUser = user;
    _authStateController.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    if (F.isFull && _useFirebase && _isFirebaseInitialized) {
      try {
        await GoogleSignIn().signOut();
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
    _mockUser = null;
    _authStateController.add(null);
  }
}
