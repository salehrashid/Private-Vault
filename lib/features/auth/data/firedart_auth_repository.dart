import 'dart:async';

import 'package:firedart/firedart.dart' as fd;

import '../../../core/errors/app_exception.dart';
import '../../../firebase/firebase_config.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

class FiredartAuthRepository implements AuthRepository {
  fd.FirebaseAuth get _auth {
    if (!firebaseConfig.isConfigured || !fd.FirebaseAuth.initialized) {
      throw const AppException('Firebase is not configured yet.');
    }
    return fd.FirebaseAuth.instance;
  }

  @override
  Stream<AuthUser?> authState() async* {
    yield currentUser();
    if (!firebaseConfig.isConfigured || !fd.FirebaseAuth.initialized) {
      return;
    }
    yield* _auth.signInState.map((signedIn) => signedIn ? currentUser() : null);
  }

  @override
  AuthUser? currentUser() {
    if (!firebaseConfig.isConfigured || !fd.FirebaseAuth.initialized) {
      return null;
    }
    if (!_auth.isSignedIn) {
      return null;
    }
    return AuthUser(uid: _auth.userId, email: '');
  }

  @override
  Future<AuthUser> signIn(String email, String password) async {
    final user = await _auth.signIn(email.trim(), password);
    return AuthUser(uid: user.id, email: user.email ?? email.trim());
  }

  @override
  Future<AuthUser> signUp(String email, String password) async {
    final user = await _auth.signUp(email.trim(), password);
    return AuthUser(uid: user.id, email: user.email ?? email.trim());
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _auth.resetPassword(email.trim());
  }

  @override
  Future<void> signOut() async {
    _auth.signOut();
  }
}
