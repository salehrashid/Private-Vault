import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/crypto/vault_crypto_service.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../auth/presentation/auth_controller.dart';
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

final unlockedVaultKeyProvider = StateProvider<SecretKey?>((ref) => null);
final selectedFolderIdProvider = StateProvider<String?>((ref) => null);
final selectedEntryProvider = StateProvider<PasswordEntry?>((ref) => null);

final hiddenFoldersProvider = StateProvider<Set<String>>((ref) => {});
final hiddenEntriesProvider = StateProvider<Set<String>>((ref) => {});

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
      await action(auth.uid, key, ref.read(vaultRepositoryProvider));
    });
  }
}
