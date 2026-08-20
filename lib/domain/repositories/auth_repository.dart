import '../entities/user.dart';

abstract class AuthRepository {
  /// Stream of authentication state changes
  Stream<UserModel?> get authStateChanges;

  /// Initiate sign-in with Google SSO
  Future<UserModel?> signInWithGoogle({String? desktopEmail, String? desktopName});

  /// Sign out
  Future<void> signOut();

  /// Get currently signed-in user
  UserModel? get currentUser;
}
