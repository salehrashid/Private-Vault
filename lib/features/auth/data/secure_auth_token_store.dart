import 'dart:async';
import 'dart:convert';

import 'package:firedart/firedart.dart' as fd;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureAuthTokenStore extends fd.TokenStore {
  SecureAuthTokenStore._(this._initialToken);

  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'firebase_auth_token';

  final fd.Token? _initialToken;

  static Future<SecureAuthTokenStore> create() async {
    try {
      final encodedToken = await _storage.read(key: _storageKey);
      return SecureAuthTokenStore._(_decodeToken(encodedToken));
    } catch (_) {
      return SecureAuthTokenStore._(null);
    }
  }

  static Future<void> clearPersistedSession() {
    return _storage.delete(key: _storageKey);
  }

  @override
  fd.Token? read() => _initialToken;

  @override
  void write(fd.Token? token) {
    final encodedToken = token == null ? null : jsonEncode(token.toMap());
    unawaited(
      _storage
          .write(key: _storageKey, value: encodedToken)
          .catchError((Object _) {}),
    );
  }

  @override
  void delete() {
    unawaited(_storage.delete(key: _storageKey).catchError((Object _) {}));
  }

  static fd.Token? _decodeToken(String? encodedToken) {
    if (encodedToken == null || encodedToken.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(encodedToken);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return fd.Token.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }
}
