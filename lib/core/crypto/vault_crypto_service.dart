import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../errors/app_exception.dart';
import 'encrypted_value.dart';

class VaultKdfConfig {
  const VaultKdfConfig({
    required this.salt,
    this.memory = 19456,
    this.iterations = 2,
    this.parallelism = 1,
    this.hashLength = 32,
  });

  final String salt;
  final int memory;
  final int iterations;
  final int parallelism;
  final int hashLength;

  Map<String, dynamic> toMap() => {
    'algorithm': 'argon2id',
    'salt': salt,
    'memory': memory,
    'iterations': iterations,
    'parallelism': parallelism,
    'hashLength': hashLength,
  };

  factory VaultKdfConfig.fromMap(Map<String, dynamic> map) {
    return VaultKdfConfig(
      salt: map['salt'] as String,
      memory: map['memory'] as int? ?? 19456,
      iterations: map['iterations'] as int? ?? 2,
      parallelism: map['parallelism'] as int? ?? 1,
      hashLength: map['hashLength'] as int? ?? 32,
    );
  }
}

class VaultCryptoService {
  VaultCryptoService() : _cipher = AesGcm.with256bits();

  final AesGcm _cipher;
  final _random = Random.secure();

  String newSalt() => base64Encode(_randomBytes(24));

  Future<SecretKey> deriveKey({
    required String masterPassword,
    required VaultKdfConfig config,
  }) {
    final algorithm = Argon2id(
      parallelism: config.parallelism,
      memory: config.memory,
      iterations: config.iterations,
      hashLength: config.hashLength,
    );

    return algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(masterPassword)),
      nonce: base64Decode(config.salt),
    );
  }

  Future<EncryptedValue> encryptString(String clearText, SecretKey key) async {
    final secretBox = await _cipher.encrypt(
      utf8.encode(clearText),
      secretKey: key,
      nonce: _randomBytes(12),
    );
    return EncryptedValue(base64Encode(secretBox.concatenation()));
  }

  Future<String> decryptString(EncryptedValue encrypted, SecretKey key) async {
    try {
      final secretBox = SecretBox.fromConcatenation(
        base64Decode(encrypted.value),
        nonceLength: _cipher.nonceLength,
        macLength: _cipher.macAlgorithm.macLength,
        copy: false,
      );
      final bytes = await _cipher.decrypt(secretBox, secretKey: key);
      return utf8.decode(bytes);
    } on Object {
      throw const AppException(
        'The master password could not decrypt this vault.',
      );
    }
  }

  List<int> _randomBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _random.nextInt(256)),
    );
  }
}
