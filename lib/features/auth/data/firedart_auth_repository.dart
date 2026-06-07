import 'dart:async';
import 'dart:io';

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
  Future<AuthUser?> verifyCurrentUser() async {
    if (!FirebaseConfig.instance.isConfigured || !fd.FirebaseAuth.initialized) {
      return null;
    }
    if (!_auth.isSignedIn) {
      return null;
    }
    try {
      final user = await _auth.getUser();
      return AuthUser(uid: user.id, email: user.email ?? '');
    } catch (error) {
      if (error is SocketException || error is TimeoutException) {
        throw const AppException(
          'Unable to connect to the server. Please check your internet connection.',
        );
      }
      final message = AuthErrorMapper.canMap(error)
          ? AuthErrorMapper.toAppException(error).message
          : '';
      final accountMissing =
          error is RangeError ||
          message == 'No account was found with this email address.' ||
          message == 'Your session has expired. Please sign in again.';
      if (accountMissing) {
        await signOut();
        throw const AppException(
          'Your account is no longer available. Please sign in again.',
        );
      }
      throw AuthErrorMapper.toAppException(error);
    }
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
      if (error is SocketException || error is TimeoutException) {
        throw const AppException(
          'Unable to connect to the server. Please check your internet connection.',
        );
      }
      throw AuthErrorMapper.toAppException(error);
    }
  }
}
