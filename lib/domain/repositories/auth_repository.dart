import '../entities/user.dart';

abstract class AuthRepository {
  /// Stream of authentication state changes
  Stream<UserModel?> get authStateChanges;

  /// Initiate sign-in with Google
  Future<UserModel?> signInWithGoogle();

  /// Sign out from Firebase and Google
  Future<void> signOut();

  /// Get currently signed-in user
  UserModel? get currentUser;
}
