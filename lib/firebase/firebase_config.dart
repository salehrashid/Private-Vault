import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseConfig {
  const FirebaseConfig({required this.projectId, required this.webApiKey});

  static const assetPath = 'assets/env';

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

  static FirebaseConfig fromEnv() {
    return FirebaseConfig(
      projectId: dotenv.env['FIREBASE_PROJECT_ID']?.trim() ?? '',
      webApiKey: dotenv.env['FIREBASE_WEB_API_KEY']?.trim() ?? '',
    );
  }
}

FirebaseConfig get firebaseConfig => FirebaseConfig.fromEnv();
