import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/network_providers.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/vault/presentation/controllers/vault_providers.dart';
import 'router.dart';
import 'theme.dart';

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class PasswordManagerApp extends ConsumerWidget {
  const PasswordManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authSessionMonitorProvider);
    ref.watch(authVaultSessionCleanupProvider);
    ref.watch(vaultOfflineSyncProvider);

    ref.listen(authSessionMessageProvider, (_, message) {
      _showSnackBar(ref, message, authSessionMessageProvider);
    });
    ref.listen(vaultSyncMessageProvider, (_, message) {
      _showSnackBar(ref, message, vaultSyncMessageProvider);
    });

    return MaterialApp.router(
      title: 'Private Vault',
      theme: AppTheme.light(),
      scaffoldMessengerKey: _scaffoldMessengerKey,
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final online = ref.watch(internetConnectionProvider).valueOrNull;
        return Column(
          children: [
            if (online == false) const _OfflineBanner(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
    );
  }

  void _showSnackBar(
    WidgetRef ref,
    String? message,
    StateProvider<String?> provider,
  ) {
    if (message == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = _scaffoldMessengerKey.currentState;
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(SnackBar(content: Text(message)));
      ref.read(provider.notifier).state = null;
    });
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, color: colors.onErrorContainer, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'You are currently offline. Changes will be synced automatically when internet access is restored.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
