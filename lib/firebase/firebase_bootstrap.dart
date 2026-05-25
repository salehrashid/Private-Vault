import 'package:firedart/firedart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../features/auth/data/secure_auth_token_store.dart';
import 'firebase_config.dart';

class FirebaseBootstrap {
  static bool _initialized = false;

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env', isOptional: true);

    final config = firebaseConfig;
    if (_initialized || !config.isConfigured) {
      return;
    }

    final tokenStore = await SecureAuthTokenStore.create();
    FirebaseAuth.initialize(config.webApiKey, tokenStore);
    Firestore.initialize(config.projectId);
    _initialized = true;
  }
}
