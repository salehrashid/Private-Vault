import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/vault/presentation/controllers/vault_providers.dart';
import '../features/vault/presentation/screens/unlock_screen.dart';
import '../features/vault/presentation/screens/vault_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _RouterRefresh(ref),
    redirect: (context, state) {
      final auth = ref.read(authStateProvider).valueOrNull;
      final key = ref.read(unlockedVaultKeyProvider);
      final path = state.uri.path;

      if (auth == null) {
        return path == '/auth' ? null : '/auth';
      }
      if (key == null) {
        return path == '/unlock' ? null : '/unlock';
      }
      if (path == '/auth' || path == '/unlock') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/unlock',
        builder: (context, state) => const UnlockScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const VaultScreen()),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this.ref) {
    ref.listen(authStateProvider, (previous, next) => notifyListeners());
    ref.listen(unlockedVaultKeyProvider, (previous, next) => notifyListeners());
  }

  final Ref ref;
}
