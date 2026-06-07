import 'dart:async';
import 'dart:io';

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
import 'local_vault_store.dart';
import 'vault_dtos.dart';

class FiredartVaultRepository implements VaultRepository {
  FiredartVaultRepository(this._crypto, {LocalVaultStore? localStore})
    : _localStore = localStore ?? LocalVaultStore();

  final VaultCryptoService _crypto;
  final LocalVaultStore _localStore;
  final _uuid = const Uuid();
  final _folderControllers = <String, StreamController<List<VaultFolder>>>{};
  final _entryControllers = <String, StreamController<List<PasswordEntry>>>{};
  final _activeKeys = <String, SecretKey>{};
  final _remoteFolderListeners = <String>{};
  final _remoteEntryListeners = <String>{};
  final _syncingUsers = <String>{};

  fd.Firestore get _firestore {
    if (!FirebaseConfig.instance.isConfigured || !fd.Firestore.initialized) {
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
    final cached = await _localStore.readMeta(uid);
    if (cached != null) {
      return cached;
    }

    try {
      final doc = _meta(uid);
      if (!await doc.exists) {
        return null;
      }
      final map = (await doc.get()).map;
      final meta = VaultMeta(
        kdfConfig: VaultKdfConfig.fromMap(
          Map<String, dynamic>.from(map['kdf']),
        ),
        verifier: map['verifier'] as String,
      );
      await _localStore.writeMeta(uid, meta);
      return meta;
    } on Object catch (error) {
      if (_isNetworkFailure(error)) {
        return null;
      }
      rethrow;
    }
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
    final metaMap = {
      'kdf': config.toMap(),
      'verifier': verifier.value,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'schemaVersion': 1,
    };
    final meta = VaultMeta(kdfConfig: config, verifier: verifier.value);
    await _localStore.writeMeta(uid, meta);
    await _localStore.enqueueOperation(
      uid,
      PendingVaultOperation(
        id: 'meta',
        type: PendingVaultOperationType.setMeta,
        createdAt: now,
        payload: metaMap,
      ),
    );
    try {
      await _meta(uid).set(metaMap);
      await syncPending(uid);
    } on Object catch (error) {
      if (!_isNetworkFailure(error)) {
        rethrow;
      }
    }
    await createFolder(uid, key, 'Personal');
    return meta;
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

  Future<void> verifyKey(String uid, SecretKey key) async {
    final meta = await loadMeta(uid);
    if (meta == null) {
      throw const AppException('No vault exists for this account yet.');
    }
    final verifier = await _crypto.decryptString(
      EncryptedValue(meta.verifier),
      key,
    );
    if (verifier != 'vault-ok') {
      throw const AppException('Invalid saved biometric unlock key.');
    }
  }

  @override
  Stream<List<VaultFolder>> watchFolders(String uid, SecretKey key) async* {
    _activeKeys[uid] = key;
    yield await _cachedFolders(uid, key);
    unawaited(_refreshFoldersFromRemote(uid, key));
    _startRemoteFolderListener(uid, key);
    yield* _folderController(uid).stream;
  }

  @override
  Stream<List<PasswordEntry>> watchEntries(
    String uid,
    String folderId,
    SecretKey key,
  ) async* {
    _activeKeys[uid] = key;
    yield await _cachedEntries(uid, folderId, key);
    unawaited(_refreshEntriesFromRemote(uid, folderId, key));
    _startRemoteEntryListener(uid, folderId, key);
    yield* _entryController(uid, folderId).stream;
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
    await _saveFolderLocal(uid, key, dto);
    await _enqueue(
      uid,
      PendingVaultOperation(
        id: 'folder:set:$id',
        type: PendingVaultOperationType.setFolder,
        createdAt: now,
        folderId: id,
        payload: dto.toMap(),
      ),
    );
  }

  @override
  Future<void> renameFolder(
    String uid,
    SecretKey key,
    String id,
    String name,
  ) async {
    final folders = await _localStore.readFolders(uid);
    final previous = folders[id];
    final now = DateTime.now().toUtc();
    final payload = {
      'name': (await _crypto.encryptString(name.trim(), key)).toMap(),
      'parentId': previous?['parentId'],
      'createdAt': previous?['createdAt'] ?? now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'schemaVersion': 1,
    };
    await _saveFolderLocal(uid, key, FolderCipherDto.fromMap(id, payload));
    await _enqueue(
      uid,
      PendingVaultOperation(
        id: 'folder:set:$id',
        type: PendingVaultOperationType.setFolder,
        createdAt: now,
        folderId: id,
        payload: payload,
      ),
    );
  }

  @override
  Future<void> deleteFolder(String uid, String folderId) async {
    final folders = await _localStore.readFolders(uid);
    folders.remove(folderId);
    await _localStore.writeFolders(uid, folders);

    final entries = await _localStore.readEntries(uid);
    entries.remove(folderId);
    await _localStore.writeEntries(uid, entries);

    await _emitFolders(uid);
    await _emitEntries(uid, folderId);
    await _enqueue(
      uid,
      PendingVaultOperation(
        id: 'folder:delete:$folderId',
        type: PendingVaultOperationType.deleteFolder,
        createdAt: DateTime.now().toUtc(),
        folderId: folderId,
      ),
    );
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
    await _saveEntryLocal(uid, key, dto);
    await _enqueue(
      uid,
      PendingVaultOperation(
        id: 'entry:set:$id',
        type: PendingVaultOperationType.setEntry,
        createdAt: now,
        folderId: entry.folderId,
        entryId: id,
        payload: dto.toMap(),
      ),
    );
  }

  @override
  Future<void> deleteEntry(String uid, String folderId, String entryId) async {
    final entries = await _localStore.readEntries(uid);
    entries[folderId]?.remove(entryId);
    await _localStore.writeEntries(uid, entries);
    await _emitEntries(uid, folderId);
    await _enqueue(
      uid,
      PendingVaultOperation(
        id: 'entry:delete:$entryId',
        type: PendingVaultOperationType.deleteEntry,
        createdAt: DateTime.now().toUtc(),
        folderId: folderId,
        entryId: entryId,
      ),
    );
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

  @override
  Future<bool> hasPendingChanges(String uid) async {
    return (await _localStore.readPendingOperations(uid)).isNotEmpty;
  }

  @override
  Future<void> syncPending(String uid) async {
    if (_syncingUsers.contains(uid)) {
      return;
    }
    _syncingUsers.add(uid);
    try {
      final operations = await _localStore.readPendingOperations(uid);
      if (operations.isEmpty) {
        return;
      }

      final remaining = <PendingVaultOperation>[];
      for (final operation in operations) {
        try {
          await _uploadOperation(uid, operation);
        } on Object catch (error) {
          if (_isNetworkFailure(error)) {
            remaining.add(operation);
            continue;
          }
          rethrow;
        }
      }
      await _localStore.writePendingOperations(uid, remaining);
    } finally {
      _syncingUsers.remove(uid);
    }
  }

  Future<void> _enqueue(String uid, PendingVaultOperation operation) async {
    await _localStore.enqueueOperation(uid, operation);
    await syncPending(uid);
  }

  Future<void> _uploadOperation(
    String uid,
    PendingVaultOperation operation,
  ) async {
    switch (operation.type) {
      case PendingVaultOperationType.setMeta:
        await _meta(uid).set(operation.payload!);
        break;
      case PendingVaultOperationType.setFolder:
        await _folders(
          uid,
        ).document(operation.folderId!).set(operation.payload!);
        break;
      case PendingVaultOperationType.deleteFolder:
        final entries = await _entries(uid, operation.folderId!).get();
        for (final entry in entries) {
          await entry.reference.delete();
        }
        await _folders(uid).document(operation.folderId!).delete();
        break;
      case PendingVaultOperationType.setEntry:
        await _entries(
          uid,
          operation.folderId!,
        ).document(operation.entryId!).set(operation.payload!);
        break;
      case PendingVaultOperationType.deleteEntry:
        await _entries(
          uid,
          operation.folderId!,
        ).document(operation.entryId!).delete();
        break;
    }
  }

  Future<void> _saveFolderLocal(
    String uid,
    SecretKey key,
    FolderCipherDto dto,
  ) async {
    final folders = await _localStore.readFolders(uid);
    folders[dto.id] = dto.toMap();
    await _localStore.writeFolders(uid, folders);
    await _emitFolders(uid, key: key);
  }

  Future<void> _saveEntryLocal(
    String uid,
    SecretKey key,
    EntryCipherDto dto,
  ) async {
    final entries = await _localStore.readEntries(uid);
    entries.putIfAbsent(dto.folderId, () => {})[dto.id] = dto.toMap();
    await _localStore.writeEntries(uid, entries);
    await _emitEntries(uid, dto.folderId, key: key);
  }

  Future<void> _refreshFoldersFromRemote(String uid, SecretKey key) async {
    try {
      final docs = await _folders(uid).get();
      final folders = <String, Map<String, dynamic>>{};
      for (final doc in docs) {
        folders[doc.id] = Map<String, dynamic>.from(doc.map);
      }
      await _localStore.writeFolders(uid, folders);
      await _reapplyPendingToCache(uid);
      await _emitFolders(uid, key: key);
    } on Object catch (error) {
      if (!_isNetworkFailure(error)) {
        rethrow;
      }
    }
  }

  Future<void> _refreshEntriesFromRemote(
    String uid,
    String folderId,
    SecretKey key,
  ) async {
    try {
      final docs = await _entries(uid, folderId).get();
      final allEntries = await _localStore.readEntries(uid);
      allEntries[folderId] = {
        for (final doc in docs) doc.id: Map<String, dynamic>.from(doc.map),
      };
      await _localStore.writeEntries(uid, allEntries);
      await _reapplyPendingToCache(uid);
      await _emitEntries(uid, folderId, key: key);
    } on Object catch (error) {
      if (!_isNetworkFailure(error)) {
        rethrow;
      }
    }
  }

  void _startRemoteFolderListener(String uid, SecretKey key) {
    if (!_remoteFolderListeners.add(uid)) {
      return;
    }
    unawaited(
      _folders(uid).stream
          .asyncMap((docs) async {
            final folders = <String, Map<String, dynamic>>{};
            for (final doc in docs) {
              folders[doc.id] = Map<String, dynamic>.from(doc.map);
            }
            await _localStore.writeFolders(uid, folders);
            await _reapplyPendingToCache(uid);
            await _emitFolders(uid, key: key);
          })
          .drain<void>()
          .catchError((Object _) {
            _remoteFolderListeners.remove(uid);
          }),
    );
  }

  void _startRemoteEntryListener(String uid, String folderId, SecretKey key) {
    final listenerKey = '$uid/$folderId';
    if (!_remoteEntryListeners.add(listenerKey)) {
      return;
    }
    unawaited(
      _entries(uid, folderId).stream
          .asyncMap((docs) async {
            final allEntries = await _localStore.readEntries(uid);
            allEntries[folderId] = {
              for (final doc in docs)
                doc.id: Map<String, dynamic>.from(doc.map),
            };
            await _localStore.writeEntries(uid, allEntries);
            await _reapplyPendingToCache(uid);
            await _emitEntries(uid, folderId, key: key);
          })
          .drain<void>()
          .catchError((Object _) {
            _remoteEntryListeners.remove(listenerKey);
          }),
    );
  }

  Future<void> _reapplyPendingToCache(String uid) async {
    final operations = await _localStore.readPendingOperations(uid);
    var folders = await _localStore.readFolders(uid);
    var entries = await _localStore.readEntries(uid);
    for (final operation in operations) {
      switch (operation.type) {
        case PendingVaultOperationType.setMeta:
          break;
        case PendingVaultOperationType.setFolder:
          folders[operation.folderId!] = operation.payload!;
          break;
        case PendingVaultOperationType.deleteFolder:
          folders.remove(operation.folderId);
          entries.remove(operation.folderId);
          break;
        case PendingVaultOperationType.setEntry:
          entries.putIfAbsent(
            operation.folderId!,
            () => {},
          )[operation.entryId!] = operation.payload!;
          break;
        case PendingVaultOperationType.deleteEntry:
          entries[operation.folderId!]?.remove(operation.entryId);
          break;
      }
    }
    await _localStore.writeFolders(uid, folders);
    await _localStore.writeEntries(uid, entries);
  }

  Future<List<VaultFolder>> _cachedFolders(String uid, SecretKey key) async {
    final folders = <VaultFolder>[];
    final cached = await _localStore.readFolders(uid);
    for (final entry in cached.entries) {
      final dto = FolderCipherDto.fromMap(entry.key, entry.value);
      folders.add(dto.toEntity(await _crypto.decryptString(dto.name, key)));
    }
    folders.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return folders;
  }

  Future<List<PasswordEntry>> _cachedEntries(
    String uid,
    String folderId,
    SecretKey key,
  ) async {
    final entries = <PasswordEntry>[];
    final cached = (await _localStore.readEntries(uid))[folderId] ?? {};
    for (final entry in cached.entries) {
      final dto = EntryCipherDto.fromMap(entry.key, entry.value);
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
  }

  Future<void> _emitFolders(String uid, {SecretKey? key}) async {
    final controller = _folderControllers[uid];
    final activeKey = key ?? _activeKeys[uid];
    if (controller == null || controller.isClosed || activeKey == null) {
      return;
    }
    controller.add(await _cachedFolders(uid, activeKey));
  }

  Future<void> _emitEntries(
    String uid,
    String folderId, {
    SecretKey? key,
  }) async {
    final controller = _entryControllers['$uid/$folderId'];
    final activeKey = key ?? _activeKeys[uid];
    if (controller == null || controller.isClosed || activeKey == null) {
      return;
    }
    controller.add(await _cachedEntries(uid, folderId, activeKey));
  }

  StreamController<List<VaultFolder>> _folderController(String uid) {
    return _folderControllers.putIfAbsent(
      uid,
      () => StreamController<List<VaultFolder>>.broadcast(),
    );
  }

  StreamController<List<PasswordEntry>> _entryController(
    String uid,
    String folderId,
  ) {
    return _entryControllers.putIfAbsent(
      '$uid/$folderId',
      () => StreamController<List<PasswordEntry>>.broadcast(),
    );
  }

  bool _isNetworkFailure(Object error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is AppException && error.message == 'No internet connection.';
  }
}
