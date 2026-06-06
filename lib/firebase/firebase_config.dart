import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseConfig {
  const FirebaseConfig({
    required this.projectId,
    required this.webApiKey,
    this.loadedAssetPath,
    this.initializationError,
  });

  static const assetPath = 'assets/env';
  static const sampleAssetPath = 'assets/env.sample';
  static const _projectIdFromDartDefine = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const _webApiKeyFromDartDefine = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
  );

  static FirebaseConfig _instance = const FirebaseConfig(
    projectId: '',
    webApiKey: '',
  );

  /// Cached singleton populated after [initFromEnv] is called.
  static FirebaseConfig get instance => _instance;

  static bool get hasCompleteDartDefineConfig {
    return _isUsableValue(_projectIdFromDartDefine) &&
        _isUsableValue(_webApiKeyFromDartDefine);
  }

  /// Read values from compile-time defines first, then dotenv, and cache them.
  static void initFromEnv({String? loadedAssetPath}) {
    _instance = FirebaseConfig(
      projectId: _firstUsableValue(
        _projectIdFromDartDefine,
        dotenv.env['FIREBASE_PROJECT_ID'],
      ),
      webApiKey: _firstUsableValue(
        _webApiKeyFromDartDefine,
        dotenv.env['FIREBASE_WEB_API_KEY'],
      ),
      loadedAssetPath: loadedAssetPath,
    );
  }

  static void markInitializationFailed(Object error) {
    _instance = FirebaseConfig(
      projectId: '',
      webApiKey: '',
      loadedAssetPath: _instance.loadedAssetPath,
      initializationError:
          'Firebase initialization failed: ${error.runtimeType}',
    );
  }

  final String projectId;
  final String webApiKey;
  final String? loadedAssetPath;
  final String? initializationError;

  bool get isConfigured =>
      initializationError == null &&
      projectId.isNotEmpty &&
      webApiKey.isNotEmpty;

  String get sourceLabel {
    if (hasCompleteDartDefineConfig) {
      return '--dart-define';
    }
    if (loadedAssetPath == assetPath && isConfigured) {
      return assetPath;
    }
    if (loadedAssetPath == sampleAssetPath) {
      return '$sampleAssetPath placeholder';
    }
    return 'unavailable';
  }

  String? get missingConfigurationMessage {
    if (initializationError != null) {
      return initializationError;
    }

    final missingKeys = <String>[
      if (projectId.isEmpty) 'FIREBASE_PROJECT_ID',
      if (webApiKey.isEmpty) 'FIREBASE_WEB_API_KEY',
    ];
    if (missingKeys.isEmpty) {
      return null;
    }
    return 'Firebase config is incomplete. Missing ${missingKeys.join(', ')} '
        'from --dart-define or $assetPath. Local development can create '
        '$assetPath from $sampleAssetPath; CI can pass --dart-define values '
        'from GitHub Secrets.';
  }

  static String _firstUsableValue(String compileTimeValue, String? envValue) {
    for (final value in [compileTimeValue, envValue]) {
      if (_isUsableValue(value)) {
        return value!.trim();
      }
    }
    return '';
  }

  static bool _isUsableValue(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isNotEmpty && !_isPlaceholder(trimmed);
  }

  static bool _isPlaceholder(String value) {
    return value.startsWith('your-') || value == '<required>';
  }
}
