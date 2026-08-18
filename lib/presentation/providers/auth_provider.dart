import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/youtube_auth_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, UserModel?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});

class AuthNotifier extends StateNotifier<UserModel?> {
  final AuthRepository _repository;
  StreamSubscription<UserModel?>? _subscription;

  AuthNotifier(this._repository) : super(_repository.currentUser) {
    _subscription = _repository.authStateChanges.listen((user) {
      state = user;
    });
  }

  Future<void> signInWithGoogle() async {
    await _repository.signInWithGoogle();
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final firebaseEnabledProvider = StateNotifierProvider<FirebaseEnabledNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FirebaseEnabledNotifier(prefs);
});

class FirebaseEnabledNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;

  FirebaseEnabledNotifier(this._prefs) : super(_prefs.getBool('use_firebase') ?? false);

  Future<void> toggle(bool value) async {
    await _prefs.setBool('use_firebase', value);
    state = value;
  }
}

// ── YouTube Music InnerTube Auth Provider ──────────────────────────────────
final youtubeAuthProvider = StateNotifierProvider<YoutubeAuthNotifier, YoutubeAuthAccount?>((ref) {
  return YoutubeAuthNotifier();
});

class YoutubeAuthNotifier extends StateNotifier<YoutubeAuthAccount?> {
  YoutubeAuthNotifier() : super(getIt<YoutubeAuthService>().account);

  Future<bool> loginWithCookie(String rawCookie, {String? name, String? email, String? photoUrl}) async {
    final success = await getIt<YoutubeAuthService>().saveCookie(
      rawCookie,
      name: name,
      email: email,
      photoUrl: photoUrl,
    );
    if (success) {
      state = getIt<YoutubeAuthService>().account;
    }
    return success;
  }

  Future<void> signOut() async {
    await getIt<YoutubeAuthService>().signOut();
    state = null;
  }
}


