import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseConfig {
  const FirebaseConfig({required this.projectId, required this.webApiKey});

  final String projectId;
  final String webApiKey;

  bool get isConfigured =>
      projectId.isNotEmpty &&
      webApiKey.isNotEmpty;

  static FirebaseConfig fromEnv() {
    return FirebaseConfig(
      projectId: dotenv.env['FIREBASE_PROJECT_ID']?.trim() ?? '',
      webApiKey: dotenv.env['FIREBASE_WEB_API_KEY']?.trim() ?? '',
    );
  }
}

FirebaseConfig get firebaseConfig => FirebaseConfig.fromEnv();
