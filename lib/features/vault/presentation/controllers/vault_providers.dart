import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/crypto/vault_crypto_service.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/biometric_vault_unlock_store.dart';
import '../../data/firedart_vault_repository.dart';
import '../../domain/password_entry.dart';
import '../../domain/vault_folder.dart';
import '../../domain/vault_repository.dart';

final vaultCryptoProvider = Provider<VaultCryptoService>((ref) {
  return VaultCryptoService();
});

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  return FiredartVaultRepository(ref.watch(vaultCryptoProvider));
});

final biometricVaultUnlockStoreProvider = Provider<BiometricVaultUnlockStore>((
  ref,
) {
  return BiometricVaultUnlockStore();
});

final biometricDeviceSupportProvider = FutureProvider<BiometricDeviceSupport>((
  ref,
) async {
  return ref.watch(biometricVaultUnlockStoreProvider).deviceSupport();
});

final biometricUnlockAvailableProvider = FutureProvider<bool>((ref) async {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) {
    return false;
  }
  return ref.watch(biometricDeviceSupportProvider.future).then((support) {
    return support.hasFingerprintHardware;
  });
});

final unlockedVaultKeyProvider = StateProvider<SecretKey?>((ref) => null);
final selectedFolderIdProvider = StateProvider<String?>((ref) => null);
final selectedEntryProvider = StateProvider<PasswordEntry?>((ref) => null);

final hiddenFoldersProvider = StateProvider<Set<String>>((ref) => {});
final hiddenEntriesProvider = StateProvider<Set<String>>((ref) => {});

final vaultRefreshControllerProvider =
    AsyncNotifierProvider<VaultRefreshController, void>(
      VaultRefreshController.new,
    );

final vaultSyncMessageProvider = StateProvider<String?>((ref) => null);

final vaultOfflineSyncProvider = Provider<void>((ref) {
  var syncing = false;

  Future<void> syncWhenReady() async {
    final auth = ref.read(authStateProvider).valueOrNull;
    final key = ref.read(unlockedVaultKeyProvider);
    final online = ref.read(internetConnectionProvider).valueOrNull;
    if (auth == null || key == null || online != true || syncing) {
      return;
    }

    final repository = ref.read(vaultRepositoryProvider);
    if (!await repository.hasPendingChanges(auth.uid)) {
      return;
    }

    syncing = true;
    ref.read(vaultSyncMessageProvider.notifier).state =
        'Connection restored. Synchronizing data...';
    try {
      await repository.syncPending(auth.uid);
      ref.invalidate(vaultFoldersProvider);
      final selectedFolderId = ref.read(selectedFolderIdProvider);
      if (selectedFolderId != null) {
        ref.invalidate(folderEntriesProvider(selectedFolderId));
      }
      if (!await repository.hasPendingChanges(auth.uid)) {
        ref.read(vaultSyncMessageProvider.notifier).state =
            'All changes have been synchronized.';
      }
    } finally {
      syncing = false;
    }
  }

  ref.listen(internetConnectionProvider, (previous, next) {
    if (previous?.valueOrNull == false && next.valueOrNull == true) {
      unawaited(syncWhenReady());
    }
  });

  ref.listen(authStateProvider, (previous, next) => unawaited(syncWhenReady()));
  ref.listen(
    unlockedVaultKeyProvider,
    (previous, next) => unawaited(syncWhenReady()),
  );
});

final authVaultSessionCleanupProvider = Provider<void>((ref) {
  ref.listen(authStateProvider, (previous, next) {
    final hadUser = previous?.valueOrNull != null;
    final hasUser = next.valueOrNull != null;
    if (!hadUser || hasUser) {
      return;
    }
    ref.read(unlockedVaultKeyProvider.notifier).state = null;
    ref.read(selectedFolderIdProvider.notifier).state = null;
    ref.read(selectedEntryProvider.notifier).state = null;
    ref.read(hiddenFoldersProvider.notifier).state = {};
    ref.read(hiddenEntriesProvider.notifier).state = {};
  });
});

final vaultFoldersProvider = StreamProvider<List<VaultFolder>>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  final key = ref.watch(unlockedVaultKeyProvider);
  if (auth == null || key == null) {
    return const Stream.empty();
  }
  return ref.watch(vaultRepositoryProvider).watchFolders(auth.uid, key);
});

final folderEntriesProvider =
    StreamProvider.family<List<PasswordEntry>, String>((ref, folderId) {
      final auth = ref.watch(authStateProvider).valueOrNull;
      final key = ref.watch(unlockedVaultKeyProvider);
      if (auth == null || key == null) {
        return const Stream.empty();
      }
      return ref
          .watch(vaultRepositoryProvider)
          .watchEntries(auth.uid, folderId, key);
    });

final vaultControllerProvider = AsyncNotifierProvider<VaultController, void>(
  VaultController.new,
);

class VaultRefreshController extends AsyncNotifier<void> {
  var _refreshing = false;

  @override
  Future<void> build() async {}

  Future<void> refresh() async {
    if (_refreshing) {
      return;
    }

    _refreshing = true;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await requireInternet(ref);
      await ref.read(authRepositoryProvider).verifyCurrentUser();
      ref.invalidate(biometricUnlockAvailableProvider);
      ref.invalidate(vaultFoldersProvider);
      final selectedFolderId = ref.read(selectedFolderIdProvider);
      if (selectedFolderId != null) {
        ref.invalidate(folderEntriesProvider(selectedFolderId));
      }
    });
    _refreshing = false;
  }
}

class VaultController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> unlock(String masterPassword) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final auth = ref.read(authStateProvider).valueOrNull;
      if (auth == null) {
        throw const AppException('Sign in before unlocking the vault.');
      }
      final repository = ref.read(vaultRepositoryProvider);
      final key = await (repository as FiredartVaultRepository).unlockKey(
        auth.uid,
        masterPassword,
      );
      await ref.read(biometricVaultUnlockStoreProvider).saveKey(auth.uid, key);
      ref.invalidate(biometricUnlockAvailableProvider);
      ref.read(unlockedVaultKeyProvider.notifier).state = key;
    });
  }

  Future<void> unlockWithBiometrics() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final auth = ref.read(authStateProvider).valueOrNull;
      if (auth == null) {
        throw const AppException('Sign in before unlocking the vault.');
      }
      final store = ref.read(biometricVaultUnlockStoreProvider);
      final key = await store.unlockWithBiometrics(auth.uid);
      if (key == null) {
        throw const AppException(
          'Unlock with the master password once before using fingerprint.',
        );
      }
      try {
        await (ref.read(vaultRepositoryProvider) as FiredartVaultRepository)
            .verifyKey(auth.uid, key);
      } catch (_) {
        await store.clearKey(auth.uid);
        ref.invalidate(biometricUnlockAvailableProvider);
        throw const AppException(
          'Saved fingerprint unlock expired. Use the master password again.',
        );
      }
      ref.read(unlockedVaultKeyProvider.notifier).state = key;
    });
  }

  Future<void> createFolder(String name, {String? parentId}) async {
    await _withVault((uid, key, repository) {
      return repository.createFolder(uid, key, name, parentId: parentId);
    });
  }

  Future<void> renameFolder(String id, String name) async {
    await _withVault((uid, key, repository) {
      return repository.renameFolder(uid, key, id, name);
    });
  }

  Future<void> deleteFolder(String id) async {
    await _withVault((uid, key, repository) async {
      await repository.deleteFolder(uid, id);
      final selected = ref.read(selectedFolderIdProvider);
      if (selected == id) {
        ref.read(selectedFolderIdProvider.notifier).state = null;
        ref.read(selectedEntryProvider.notifier).state = null;
      }
    });
  }

  Future<void> saveEntry(PasswordEntry entry) async {
    await _withVault((uid, key, repository) {
      return repository.saveEntry(uid, key, entry);
    });
  }

  Future<void> deleteEntry(PasswordEntry entry) async {
    await _withVault((uid, key, repository) async {
      await repository.deleteEntry(uid, entry.folderId, entry.id);
      ref.read(selectedEntryProvider.notifier).state = null;
    });
  }

  Future<void> moveEntry(PasswordEntry entry, String targetFolderId) async {
    await _withVault((uid, key, repository) {
      return repository.moveEntry(
        uid: uid,
        key: key,
        entry: entry,
        targetFolderId: targetFolderId,
      );
    });
  }

  Future<void> lock() async {
    ref.read(unlockedVaultKeyProvider.notifier).state = null;
    ref.read(selectedFolderIdProvider.notifier).state = null;
    ref.read(selectedEntryProvider.notifier).state = null;
  }

  Future<void> _withVault(
    Future<void> Function(String uid, SecretKey key, VaultRepository repository)
    action,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final auth = ref.read(authStateProvider).valueOrNull;
      final key = ref.read(unlockedVaultKeyProvider);
      if (auth == null || key == null) {
        throw const AppException('Unlock the vault first.');
      }
      if (ref.read(internetConnectionProvider).valueOrNull != false) {
        await ref.read(authRepositoryProvider).verifyCurrentUser();
      }
      await action(auth.uid, key, ref.read(vaultRepositoryProvider));
    });
  }
}
