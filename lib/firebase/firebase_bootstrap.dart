import 'package:firedart/firedart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../features/auth/data/secure_auth_token_store.dart';
import 'firebase_config.dart';

class FirebaseBootstrap {
  static bool _initialized = false;

  static Future<void> initialize() async {
    final loadedAssetPath = await _loadOptionalEnv();

    FirebaseConfig.initFromEnv(loadedAssetPath: loadedAssetPath);
    final config = FirebaseConfig.instance;

    if (_initialized || !config.isConfigured) {
      if (!config.isConfigured) {
        debugPrint('[FirebaseBootstrap] ${config.missingConfigurationMessage}');
      }
      return;
    }

    final tokenStore = await SecureAuthTokenStore.create();
    FirebaseAuth.initialize(config.webApiKey, tokenStore);
    Firestore.initialize(config.projectId);
    _initialized = true;
  }

  static Future<String?> _loadOptionalEnv() async {
    if (const String.fromEnvironment('FIREBASE_PROJECT_ID').trim().isNotEmpty &&
        const String.fromEnvironment(
          'FIREBASE_WEB_API_KEY',
        ).trim().isNotEmpty) {
      return null;
    }

    if (await _tryLoadEnvAsset(FirebaseConfig.assetPath)) {
      return FirebaseConfig.assetPath;
    }

    if (await _tryLoadEnvAsset(FirebaseConfig.sampleAssetPath)) {
      return FirebaseConfig.sampleAssetPath;
    }

    return null;
  }

  static Future<bool> _tryLoadEnvAsset(String assetPath) async {
    try {
      await dotenv.load(fileName: assetPath);
      if (assetPath == FirebaseConfig.sampleAssetPath) {
        debugPrint(
          '[FirebaseBootstrap] Loaded ${FirebaseConfig.sampleAssetPath}. '
          'Firebase remains disabled until real config is provided.',
        );
      }
      return true;
    } catch (e) {
      if (assetPath == FirebaseConfig.assetPath) {
        debugPrint(
          '[FirebaseBootstrap] ${FirebaseConfig.assetPath} was not found. '
          'Falling back to ${FirebaseConfig.sampleAssetPath}.',
        );
      } else {
        debugPrint('[FirebaseBootstrap] Failed to load $assetPath: $e');
      }
      return false;
    }
  }
}
