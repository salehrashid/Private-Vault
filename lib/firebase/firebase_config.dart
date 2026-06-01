import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseConfig {
  const FirebaseConfig({
    required this.projectId,
    required this.webApiKey,
    this.loadedAssetPath,
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

  final String projectId;
  final String webApiKey;
  final String? loadedAssetPath;

  bool get isConfigured => projectId.isNotEmpty && webApiKey.isNotEmpty;

  String? get missingConfigurationMessage {
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
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty && !_isPlaceholder(trimmed)) {
        return trimmed;
      }
    }
    return '';
  }

  static bool _isPlaceholder(String value) {
    return value.startsWith('your-') || value == '<required>';
  }
}
