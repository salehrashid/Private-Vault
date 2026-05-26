import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_messages.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/biometric_vault_unlock_store.dart';
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
                  decoration: const InputDecoration(
                    labelText: 'Master password',
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
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: OutlinedButton.icon(
                    onPressed: busy || !hasFingerprintHardware
                        ? null
                        : _unlockWithFingerprint,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Unlock with fingerprint'),
                  ),
                ),
                const SizedBox(height: 8),
                // Text(
                //   biometricSupport.maybeWhen(
                //     data: _fingerprintSupportText,
                //     loading: () => 'Checking fingerprint hardware...',
                //     orElse: () => 'Fingerprint hardware status unavailable.',
                //   ),
                //   textAlign: TextAlign.center,
                //   style: Theme.of(context).textTheme.bodySmall,
                // ),
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

  String _fingerprintSupportText(BiometricDeviceSupport support) {
    if (!support.hasFingerprintHardware) {
      return 'Fingerprint hardware not detected on this device.';
    }
    if (!support.hasEnrolledBiometrics) {
      return 'Fingerprint hardware detected. Enroll fingerprint in Android settings first.';
    }
    return 'Fingerprint hardware detected.';
  }
}
