import 'auth_user.dart';

abstract class AuthRepository {
  Stream<AuthUser?> authState();
  AuthUser? currentUser();
  Future<AuthUser> signIn(String email, String password);
  Future<AuthUser> signUp(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}
