import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseConfig {
  const FirebaseConfig({required this.projectId, required this.webApiKey});

  static const assetPath = 'assets/env';

  static FirebaseConfig _instance = const FirebaseConfig(
    projectId: '',
    webApiKey: '',
  );

  /// Cached singleton populated after [initFromEnv] is called.
  static FirebaseConfig get instance => _instance;

  /// Read values from dotenv once and cache them.
  static void initFromEnv() {
    _instance = FirebaseConfig(
      projectId: dotenv.env['FIREBASE_PROJECT_ID']?.trim() ?? '',
      webApiKey: dotenv.env['FIREBASE_WEB_API_KEY']?.trim() ?? '',
    );
  }

  final String projectId;
  final String webApiKey;

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
        'in $assetPath.';
  }
}
