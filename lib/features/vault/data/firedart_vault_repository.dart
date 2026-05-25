import 'package:cryptography/cryptography.dart';
import 'package:firedart/firedart.dart' as fd;
import 'package:uuid/uuid.dart';

import '../../../core/crypto/encrypted_value.dart';
import '../../../core/crypto/vault_crypto_service.dart';
import '../../../core/errors/app_exception.dart';
import '../../../firebase/firebase_config.dart';
import '../domain/password_entry.dart';
import '../domain/vault_folder.dart';
import '../domain/vault_meta.dart';
import '../domain/vault_repository.dart';
import 'vault_dtos.dart';

class FiredartVaultRepository implements VaultRepository {
  FiredartVaultRepository(this._crypto);

  final VaultCryptoService _crypto;
  final _uuid = const Uuid();

  fd.Firestore get _firestore {
    if (!firebaseConfig.isConfigured || !fd.Firestore.initialized) {
      throw const AppException('Firebase is not configured yet.');
    }
    return fd.Firestore.instance;
  }

  fd.DocumentReference _userDoc(String uid) {
    return _firestore.collection('users').document(uid);
  }

  fd.CollectionReference _folders(String uid) {
    return _userDoc(uid).collection('folders');
  }

  fd.CollectionReference _entries(String uid, String folderId) {
    return _folders(uid).document(folderId).collection('entries');
  }

  fd.DocumentReference _meta(String uid) {
    return _userDoc(uid).collection('vault').document('meta');
  }

  @override
  Future<VaultMeta?> loadMeta(String uid) async {
    final doc = _meta(uid);
    if (!await doc.exists) {
      return null;
    }
    final map = (await doc.get()).map;
    return VaultMeta(
      kdfConfig: VaultKdfConfig.fromMap(Map<String, dynamic>.from(map['kdf'])),
      verifier: map['verifier'] as String,
    );
  }

  @override
  Future<VaultMeta> createVault(String uid, String masterPassword) async {
    final config = VaultKdfConfig(salt: _crypto.newSalt());
    final key = await _crypto.deriveKey(
      masterPassword: masterPassword,
      config: config,
    );
    final verifier = await _crypto.encryptString('vault-ok', key);
    final now = DateTime.now().toUtc();
    await _meta(uid).set({
      'kdf': config.toMap(),
      'verifier': verifier.value,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'schemaVersion': 1,
    });
    await createFolder(uid, key, 'Personal');
    return VaultMeta(kdfConfig: config, verifier: verifier.value);
  }

  @override
  Future<void> verifyMasterPassword(String uid, String masterPassword) async {
    final meta = await loadMeta(uid);
    if (meta == null) {
      throw const AppException('No vault exists for this account yet.');
    }
    final key = await _crypto.deriveKey(
      masterPassword: masterPassword,
      config: meta.kdfConfig,
    );
    final verifier = await _crypto.decryptString(
      EncryptedValue(meta.verifier),
      key,
    );
    if (verifier != 'vault-ok') {
      throw const AppException('Invalid master password.');
    }
  }

  Future<SecretKey> unlockKey(String uid, String masterPassword) async {
    final meta = await loadMeta(uid);
    if (meta == null) {
      await createVault(uid, masterPassword);
      return unlockKey(uid, masterPassword);
    }
    final key = await _crypto.deriveKey(
      masterPassword: masterPassword,
      config: meta.kdfConfig,
    );
    final verifier = await _crypto.decryptString(
      EncryptedValue(meta.verifier),
      key,
    );
    if (verifier != 'vault-ok') {
      throw const AppException('Invalid master password.');
    }
    return key;
  }

  @override
  Stream<List<VaultFolder>> watchFolders(String uid, SecretKey key) {
    return _folders(uid).stream.asyncMap((docs) async {
      final folders = <VaultFolder>[];
      for (final doc in docs) {
        final dto = FolderCipherDto.fromMap(doc.id, doc.map);
        folders.add(dto.toEntity(await _crypto.decryptString(dto.name, key)));
      }
      folders.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return folders;
    });
  }

  @override
  Stream<List<PasswordEntry>> watchEntries(
    String uid,
    String folderId,
    SecretKey key,
  ) {
    return _entries(uid, folderId).stream.asyncMap((docs) async {
      final entries = <PasswordEntry>[];
      for (final doc in docs) {
        final dto = EntryCipherDto.fromMap(doc.id, doc.map);
        entries.add(
          dto.toEntity(
            title: await _crypto.decryptString(dto.title, key),
            username: await _crypto.decryptString(dto.username, key),
            password: await _crypto.decryptString(dto.password, key),
            url: await _crypto.decryptString(dto.url, key),
            notes: await _crypto.decryptString(dto.notes, key),
          ),
        );
      }
      entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return entries;
    });
  }

  @override
  Future<void> createFolder(
    String uid,
    SecretKey key,
    String name, {
    String? parentId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    final dto = FolderCipherDto(
      id: id,
      name: await _crypto.encryptString(name.trim(), key),
      parentId: parentId,
      createdAt: now,
      updatedAt: now,
    );
    await _folders(uid).document(id).set(dto.toMap());
  }

  @override
  Future<void> renameFolder(
    String uid,
    SecretKey key,
    String id,
    String name,
  ) async {
    await _folders(uid).document(id).update({
      'name': (await _crypto.encryptString(name.trim(), key)).toMap(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> deleteFolder(String uid, String folderId) async {
    final entries = await _entries(uid, folderId).get();
    for (final entry in entries) {
      await entry.reference.delete();
    }
    await _folders(uid).document(folderId).delete();
  }

  @override
  Future<void> saveEntry(String uid, SecretKey key, PasswordEntry entry) async {
    final now = DateTime.now().toUtc();
    final isNew = entry.id.isEmpty;
    final id = isNew ? _uuid.v4() : entry.id;
    final dto = EntryCipherDto(
      id: id,
      folderId: entry.folderId,
      title: await _crypto.encryptString(entry.title.trim(), key),
      username: await _crypto.encryptString(entry.username.trim(), key),
      password: await _crypto.encryptString(entry.password, key),
      url: await _crypto.encryptString(entry.url ?? '', key),
      notes: await _crypto.encryptString(entry.notes ?? '', key),
      createdAt: isNew ? now : entry.createdAt,
      updatedAt: now,
    );
    await _entries(uid, entry.folderId).document(id).set(dto.toMap());
  }

  @override
  Future<void> deleteEntry(String uid, String folderId, String entryId) {
    return _entries(uid, folderId).document(entryId).delete();
  }

  @override
  Future<void> moveEntry({
    required String uid,
    required SecretKey key,
    required PasswordEntry entry,
    required String targetFolderId,
  }) async {
    await saveEntry(uid, key, entry.copyWith(folderId: targetFolderId));
    await deleteEntry(uid, entry.folderId, entry.id);
  }
}
