import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_messages.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../controllers/vault_providers.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _masterPassword = TextEditingController();

  @override
  void dispose() {
    _masterPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(vaultControllerProvider, (_, next) {
      final error = next.error;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(error))));
      }
    });

    final busy = ref.watch(vaultControllerProvider).isLoading;
    final biometricSupport = ref.watch(biometricDeviceSupportProvider);
    final hasFingerprintHardware = biometricSupport.maybeWhen(
      data: (support) => support.hasFingerprintHardware,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Private Vault'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Unlock vault',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Use the master password that encrypts your vault. It is separate from your Firebase account password.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _masterPassword,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Master password',
                    suffixIcon: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: Tooltip(
                        message: hasFingerprintHardware
                            ? 'Unlock with fingerprint'
                            : 'Fingerprint unavailable',
                        child: IconButton.filledTonal(
                          onPressed: busy || !hasFingerprintHardware
                              ? null
                              : _unlockWithFingerprint,
                          icon: const Icon(Icons.fingerprint),
                          iconSize: 22,
                          style: IconButton.styleFrom(
                            fixedSize: const Size.square(40),
                            minimumSize: const Size.square(40),
                            padding: EdgeInsets.zero,
                            shape: const CircleBorder(),
                          ),
                        ),
                      ),
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 56,
                      minHeight: 48,
                    ),
                  ),
                  onSubmitted: (_) => _unlock(),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: busy ? null : _unlock,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_open),
                  label: const Text('Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _unlock() {
    ref.read(vaultControllerProvider.notifier).unlock(_masterPassword.text);
  }

  void _unlockWithFingerprint() {
    ref.read(vaultControllerProvider.notifier).unlockWithBiometrics();
  }
}
