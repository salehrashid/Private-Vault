import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/errors/app_exception.dart';

class BiometricVaultUnlockStore {
  static const _deviceBiometricsChannel = MethodChannel(
    'password_manager/device_biometrics',
  );

  BiometricVaultUnlockStore({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _localAuth = localAuth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  Future<BiometricDeviceSupport> deviceSupport() async {
    var nativeSupport = const BiometricDeviceSupport();
    try {
      final nativeResult = await _deviceBiometricsChannel
          .invokeMapMethod<String, Object?>('getBiometricSupport');
      nativeSupport = BiometricDeviceSupport.fromMap(nativeResult);
    } on MissingPluginException {
      nativeSupport = const BiometricDeviceSupport(platform: 'unsupported');
    } catch (_) {
      nativeSupport = const BiometricDeviceSupport();
    }

    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final biometrics = await _localAuth.getAvailableBiometrics();
      final supported = await _localAuth.isDeviceSupported();
      return nativeSupport.copyWith(
        canAuthenticateWithLocalAuth: supported && canCheck,
        enrolledBiometrics: biometrics.map((type) => type.name).toList(),
      );
    } catch (_) {
      return nativeSupport;
    }
  }

  Future<bool> canUseBiometrics() async {
    return (await deviceSupport()).hasFingerprintHardware;
  }

  Future<bool> hasSavedKey(String uid) async {
    final encodedKey = await _storage.read(key: _storageKey(uid));
    return encodedKey != null && encodedKey.isNotEmpty;
  }

  Future<void> saveKey(String uid, SecretKey key) async {
    final keyBytes = await key.extractBytes();
    await _storage.write(key: _storageKey(uid), value: base64Encode(keyBytes));
  }

  Future<SecretKey?> unlockWithBiometrics(String uid) async {
    final encodedKey = await _storage.read(key: _storageKey(uid));
    if (encodedKey == null || encodedKey.isEmpty) {
      return null;
    }

    final authenticated = await _authenticate(await deviceSupport());
    if (!authenticated) {
      return null;
    }

    return SecretKey(base64Decode(encodedKey));
  }

  Future<void> clearKey(String uid) {
    return _storage.delete(key: _storageKey(uid));
  }

  String _storageKey(String uid) => 'vault_biometric_key_$uid';

  Future<bool> _authenticate(BiometricDeviceSupport support) async {
    if (support.hasFingerprintHardware) {
      return _authenticateWithNativeFingerprint();
    }

    try {
      return await _runLocalAuth(biometricOnly: true);
    } on LocalAuthException catch (error) {
      switch (error.code) {
        case LocalAuthExceptionCode.noBiometricsEnrolled:
          throw const AppException(
            'No fingerprint is enrolled on this device.',
          );
        case LocalAuthExceptionCode.noBiometricHardware:
          throw const AppException(
            'Fingerprint hardware was detected, but Android biometric prompt is not available.',
          );
        case LocalAuthExceptionCode.noCredentialsSet:
          throw const AppException(
            'Set a screen lock and fingerprint in Android settings first.',
          );
        case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
          throw const AppException(
            'Fingerprint hardware is temporarily unavailable.',
          );
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          throw const AppException(
            'Fingerprint is locked. Unlock your phone once and try again.',
          );
        case LocalAuthExceptionCode.uiUnavailable:
          throw AppException(
            error.description ?? 'Fingerprint prompt is unavailable.',
          );
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.userRequestedFallback:
        case LocalAuthExceptionCode.systemCanceled:
        case LocalAuthExceptionCode.timeout:
          return false;
        case LocalAuthExceptionCode.authInProgress:
          throw const AppException('Fingerprint unlock is already running.');
        case LocalAuthExceptionCode.deviceError:
        case LocalAuthExceptionCode.unknownError:
          throw AppException(error.description ?? 'Fingerprint unlock failed.');
      }
    }
  }

  Future<bool> _runLocalAuth({required bool biometricOnly}) {
    return _localAuth.authenticate(
      localizedReason: 'Use fingerprint to unlock your vault.',
      biometricOnly: biometricOnly,
      persistAcrossBackgrounding: true,
    );
  }

  Future<bool> _authenticateWithNativeFingerprint() async {
    try {
      return await _deviceBiometricsChannel.invokeMethod<bool>(
            'authenticateFingerprint',
          ) ??
          false;
    } on PlatformException catch (error) {
      throw AppException(error.message ?? 'Fingerprint unlock failed.');
    } on MissingPluginException {
      return _runLocalAuth(biometricOnly: true);
    }
  }
}

class BiometricDeviceSupport {
  const BiometricDeviceSupport({
    this.platform = 'unknown',
    this.sdkInt,
    this.hasFingerprintHardware = false,
    this.hasBiometricHardware = false,
    this.hasEnrolledBiometricsFromAndroid = false,
    this.biometricAuthStatus,
    this.canAuthenticateWithLocalAuth = false,
    this.enrolledBiometrics = const [],
  });

  final String platform;
  final int? sdkInt;
  final bool hasFingerprintHardware;
  final bool hasBiometricHardware;
  final bool hasEnrolledBiometricsFromAndroid;
  final int? biometricAuthStatus;
  final bool canAuthenticateWithLocalAuth;
  final List<String> enrolledBiometrics;

  bool get hasEnrolledBiometrics =>
      hasEnrolledBiometricsFromAndroid || enrolledBiometrics.isNotEmpty;

  BiometricDeviceSupport copyWith({
    bool? canAuthenticateWithLocalAuth,
    List<String>? enrolledBiometrics,
  }) {
    return BiometricDeviceSupport(
      platform: platform,
      sdkInt: sdkInt,
      hasFingerprintHardware: hasFingerprintHardware,
      hasBiometricHardware: hasBiometricHardware,
      hasEnrolledBiometricsFromAndroid: hasEnrolledBiometricsFromAndroid,
      biometricAuthStatus: biometricAuthStatus,
      canAuthenticateWithLocalAuth:
          canAuthenticateWithLocalAuth ?? this.canAuthenticateWithLocalAuth,
      enrolledBiometrics: enrolledBiometrics ?? this.enrolledBiometrics,
    );
  }

  factory BiometricDeviceSupport.fromMap(Map<String, Object?>? map) {
    if (map == null) {
      return const BiometricDeviceSupport();
    }
    return BiometricDeviceSupport(
      platform: map['platform'] as String? ?? 'unknown',
      sdkInt: map['sdkInt'] as int?,
      hasFingerprintHardware: map['hasFingerprintHardware'] as bool? ?? false,
      hasBiometricHardware: map['hasBiometricHardware'] as bool? ?? false,
      hasEnrolledBiometricsFromAndroid:
          map['hasEnrolledBiometrics'] as bool? ?? false,
      biometricAuthStatus: map['biometricAuthStatus'] as int?,
    );
  }
}
