import 'package:cryptography/cryptography.dart';

import 'password_entry.dart';
import 'vault_folder.dart';
import 'vault_meta.dart';

abstract class VaultRepository {
  Future<VaultMeta?> loadMeta(String uid);
  Future<VaultMeta> createVault(String uid, String masterPassword);
  Future<void> verifyMasterPassword(String uid, String masterPassword);
  Stream<List<VaultFolder>> watchFolders(String uid, SecretKey key);
  Stream<List<PasswordEntry>> watchEntries(
    String uid,
    String folderId,
    SecretKey key,
  );
  Future<void> createFolder(
    String uid,
    SecretKey key,
    String name, {
    String? parentId,
  });
  Future<void> renameFolder(String uid, SecretKey key, String id, String name);
  Future<void> deleteFolder(String uid, String folderId);
  Future<void> saveEntry(String uid, SecretKey key, PasswordEntry entry);
  Future<void> deleteEntry(String uid, String folderId, String entryId);
  Future<void> moveEntry({
    required String uid,
    required SecretKey key,
    required PasswordEntry entry,
    required String targetFolderId,
  });
}
