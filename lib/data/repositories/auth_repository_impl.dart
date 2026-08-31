import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../flavors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/logger.dart';
import '../../core/services/desktop_auth_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthRepositoryImpl(prefs);
});

class AuthRepositoryImpl implements AuthRepository {
  final SharedPreferences _prefs;
  final StreamController<UserModel?> _authStateController = StreamController<UserModel?>.broadcast();
  final _log = AppLogger('AuthRepository');
  UserModel? _mockUser;
  bool _isFirebaseInitialized = false;

  AuthRepositoryImpl(this._prefs) {
    _init();
  }

  bool get _useFirebase => _prefs.getBool('use_firebase') ?? true;

  void _init() {
    // Restore saved user session if any
    final savedUid = _prefs.getString('auth_user_uid');
    final savedName = _prefs.getString('auth_user_name');
    final savedEmail = _prefs.getString('auth_user_email');
    final savedPhoto = _prefs.getString('auth_user_photo');
    if (savedUid != null && savedName != null) {
      _mockUser = UserModel(
        uid: savedUid,
        displayName: savedName,
        email: savedEmail,
        photoUrl: savedPhoto,
      );
    }

    if (F.isFull && _useFirebase && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
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

            // Track user in Firebase Analytics Dashboard
            try {
              FirebaseAnalytics.instance.setUserId(id: user.uid);
            } catch (_) {}
          } else {
            _authStateController.add(_mockUser);
          }
        });
        _isFirebaseInitialized = true;
        return;
      } catch (e) {
        _log.error('Firebase Auth listener init failed: $e');
      }
    }
    _authStateController.add(_mockUser);
  }

  @override
  Stream<UserModel?> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser {
    if (F.isFull && _useFirebase && _isFirebaseInitialized && (Platform.isAndroid || Platform.isIOS)) {
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
  Future<UserModel?> signInWithGoogle({String? desktopEmail, String? desktopName}) async {
    if (F.isFull && _useFirebase) {
      try {
        if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
          // Real browser-redirect Google SSO for Windows Desktop
          final user = await DesktopAuthService.signInWithGoogleDesktop();
          if (user != null) {
            _saveUserSession(user);
            _mockUser = user;
            _authStateController.add(user);
            return user;
          }
          return null;
        }

        if (kIsWeb) {
          final GoogleAuthProvider googleProvider = GoogleAuthProvider();
          googleProvider.addScope('email');
          googleProvider.addScope('profile');

          final UserCredential userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);

          final firebaseUser = userCredential.user;

          if (firebaseUser != null) {
            final user = UserModel(
              uid: firebaseUser.uid,
              displayName: firebaseUser.displayName ?? 'Google User',
              email: firebaseUser.email,
              photoUrl: firebaseUser.photoURL,
            );
            _saveUserSession(user);
            _authStateController.add(user);
            return user;
          }
        }

        // Android / iOS native flow with Google Play Services
        try {
          GoogleSignInAccount? googleUser;
          try {
            final GoogleSignIn googleSignIn = GoogleSignIn(
              serverClientId: '606758484923-6i764cbhhqa30thjn5nssljvcre593p7.apps.googleusercontent.com',
              scopes: const ['email'],
            );
            googleUser = await googleSignIn.signIn();
          } catch (e) {
            _log.warning('GoogleSignIn with serverClientId failed ($e), trying standard GoogleSignIn...');
            try {
              final GoogleSignIn googleSignIn = GoogleSignIn(scopes: const ['email']);
              googleUser = await googleSignIn.signIn();
            } catch (e2) {
              _log.warning('Standard GoogleSignIn also failed: $e2');
            }
          }

          if (googleUser != null) {
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
                displayName: firebaseUser.displayName ?? googleUser.displayName ?? 'Google User',
                email: firebaseUser.email ?? googleUser.email,
                photoUrl: firebaseUser.photoURL ?? googleUser.photoUrl,
              );

              try {
                if (!kIsWeb) {
                  await FirebaseAnalytics.instance.setUserId(id: user.uid);
                  await FirebaseAnalytics.instance.setUserProperty(name: 'auth_method', value: 'google_sso');
                  await FirebaseAnalytics.instance.logLogin(loginMethod: 'google_sso');
                }
              } catch (_) {}

              _saveUserSession(user);
              _authStateController.add(user);
              return user;
            }
          }
        } catch (e) {
          _log.warning('Native Google Play Services Sign-In failed ($e), falling back to browser Google SSO...');
        }

        // Fallback to Google SSO (works seamlessly across all devices)
        _log.info('Initiating 1-click Google SSO flow...');
        final user = await DesktopAuthService.signInWithGoogleDesktop();
        if (user != null) {
          _saveUserSession(user);
          _mockUser = user;
          _authStateController.add(user);
          return user;
        }
      } catch (e, st) {
        _log.error('Google Sign-In failed: $e', e, st);
        rethrow;
      }
    }
    return null;
  }

  void _saveUserSession(UserModel user) {
    _prefs.setString('auth_user_uid', user.uid);
    _prefs.setString('auth_user_name', user.displayName);
    if (user.email != null) _prefs.setString('auth_user_email', user.email!);
    if (user.photoUrl != null) _prefs.setString('auth_user_photo', user.photoUrl!);
  }

  @override
  Future<void> signOut() async {
    if (F.isFull && _useFirebase && _isFirebaseInitialized) {
      try {
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          await GoogleSignIn().signOut();
          await FirebaseAuth.instance.signOut();
        }
      } catch (e) {
        _log.error('SignOut error: $e');
      }
    }
    await _prefs.remove('auth_user_uid');
    await _prefs.remove('auth_user_name');
    await _prefs.remove('auth_user_email');
    await _prefs.remove('auth_user_photo');
    _mockUser = null;
    _authStateController.add(null);
  }
}
