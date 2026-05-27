import 'dart:async';

import 'package:firedart/firedart.dart' as fd;

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/auth_error_mapper.dart';
import '../../../firebase/firebase_config.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import 'secure_auth_token_store.dart';

class FiredartAuthRepository implements AuthRepository {
  fd.FirebaseAuth get _auth {
    if (!FirebaseConfig.instance.isConfigured || !fd.FirebaseAuth.initialized) {
      throw const AppException('Firebase is not configured yet.');
    }
    return fd.FirebaseAuth.instance;
  }

  @override
  Stream<AuthUser?> authState() async* {
    yield currentUser();
    if (!FirebaseConfig.instance.isConfigured || !fd.FirebaseAuth.initialized) {
      return;
    }
    yield* _auth.signInState.map((signedIn) => signedIn ? currentUser() : null);
  }

  @override
  AuthUser? currentUser() {
    if (!FirebaseConfig.instance.isConfigured || !fd.FirebaseAuth.initialized) {
      return null;
    }
    if (!_auth.isSignedIn) {
      return null;
    }
    return AuthUser(uid: _auth.userId, email: '');
  }

  @override
  Future<AuthUser> signIn(String email, String password) async {
    return _mapAuthErrors(() async {
      final normalizedEmail = email.trim();
      final user = await _auth.signIn(normalizedEmail, password);
      return AuthUser(uid: user.id, email: user.email ?? normalizedEmail);
    });
  }

  @override
  Future<AuthUser> signUp(String email, String password) async {
    return _mapAuthErrors(() async {
      final normalizedEmail = email.trim();
      final user = await _auth.signUp(normalizedEmail, password);
      return AuthUser(uid: user.id, email: user.email ?? normalizedEmail);
    });
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _mapAuthErrors(() => _auth.resetPassword(email.trim()));
  }

  @override
  Future<void> signOut() async {
    _auth.signOut();
    await SecureAuthTokenStore.clearPersistedSession();
  }

  Future<T> _mapAuthErrors<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw AuthErrorMapper.toAppException(error);
    }
  }
}
