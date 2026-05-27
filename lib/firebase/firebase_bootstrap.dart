import 'package:firedart/firedart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../features/auth/data/secure_auth_token_store.dart';
import 'firebase_config.dart';

class FirebaseBootstrap {
  static bool _initialized = false;

  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: FirebaseConfig.assetPath);
    } catch (e) {
      debugPrint(
        '[FirebaseBootstrap] Failed to load ${FirebaseConfig.assetPath}: $e\n'
        'Ensure the asset is declared in pubspec.yaml and bundled in the build.',
      );
    }

    FirebaseConfig.initFromEnv();
    final config = FirebaseConfig.instance;

    if (_initialized || !config.isConfigured) {
      if (!config.isConfigured) {
        debugPrint(
          '[FirebaseBootstrap] ${config.missingConfigurationMessage}',
        );
      }
      return;
    }

    final tokenStore = await SecureAuthTokenStore.create();
    FirebaseAuth.initialize(config.webApiKey, tokenStore);
    Firestore.initialize(config.projectId);
    _initialized = true;
  }
}
