import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/crypto/vault_crypto_service.dart';
import '../domain/vault_meta.dart';

class LocalVaultStore {
  LocalVaultStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<VaultMeta?> readMeta(String uid) async {
    final encoded = await _readJson(_metaKey(uid));
    if (encoded == null) {
      return null;
    }
    return VaultMeta(
      kdfConfig: VaultKdfConfig.fromMap(
        Map<String, dynamic>.from(encoded['kdf']),
      ),
      verifier: encoded['verifier'] as String,
    );
  }

  Future<void> writeMeta(String uid, VaultMeta meta) {
    return _writeJson(_metaKey(uid), {
      'kdf': meta.kdfConfig.toMap(),
      'verifier': meta.verifier,
    });
  }

  Future<Map<String, Map<String, dynamic>>> readFolders(String uid) async {
    return _readNestedMap(_foldersKey(uid));
  }

  Future<void> writeFolders(
    String uid,
    Map<String, Map<String, dynamic>> folders,
  ) {
    return _writeJson(_foldersKey(uid), folders);
  }

  Future<Map<String, Map<String, Map<String, dynamic>>>> readEntries(
    String uid,
  ) async {
    final decoded = await _readJson(_entriesKey(uid));
    if (decoded == null) {
      return {};
    }
    return decoded.map((folderId, value) {
      final entries = Map<String, dynamic>.from(value as Map);
      return MapEntry(
        folderId,
        entries.map(
          (entryId, entryValue) =>
              MapEntry(entryId, Map<String, dynamic>.from(entryValue as Map)),
        ),
      );
    });
  }

  Future<void> writeEntries(
    String uid,
    Map<String, Map<String, Map<String, dynamic>>> entries,
  ) {
    return _writeJson(_entriesKey(uid), entries);
  }

  Future<List<PendingVaultOperation>> readPendingOperations(String uid) async {
    final decoded = await _readJson(_pendingKey(uid));
    if (decoded == null) {
      return [];
    }
    final items = decoded['items'];
    if (items is! List) {
      return [];
    }
    return items
        .whereType<Map>()
        .map((item) => PendingVaultOperation.fromMap(item))
        .toList();
  }

  Future<void> writePendingOperations(
    String uid,
    List<PendingVaultOperation> operations,
  ) {
    return _writeJson(_pendingKey(uid), {
      'items': operations.map((operation) => operation.toMap()).toList(),
    });
  }

  Future<void> enqueueOperation(
    String uid,
    PendingVaultOperation operation,
  ) async {
    final operations = await readPendingOperations(uid);
    operations.removeWhere((item) => item.id == operation.id);
    operations.add(operation);
    await writePendingOperations(uid, _compact(operations));
  }

  Future<Map<String, dynamic>?> _readJson(String key) async {
    final encoded = await _storage.read(key: key);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, Map<String, dynamic>>> _readNestedMap(String key) async {
    final decoded = await _readJson(key);
    if (decoded == null) {
      return {};
    }
    return decoded.map(
      (id, value) => MapEntry(id, Map<String, dynamic>.from(value as Map)),
    );
  }

  Future<void> _writeJson(String key, Object value) {
    return _storage.write(key: key, value: jsonEncode(value));
  }

  List<PendingVaultOperation> _compact(List<PendingVaultOperation> operations) {
    final compacted = <PendingVaultOperation>[];
    for (final operation in operations) {
      compacted.removeWhere((item) {
        if (operation.type == PendingVaultOperationType.deleteFolder) {
          return item.folderId == operation.folderId;
        }
        if (operation.type == PendingVaultOperationType.setFolder) {
          return item.type == PendingVaultOperationType.setFolder &&
              item.folderId == operation.folderId;
        }
        if (operation.type == PendingVaultOperationType.deleteEntry) {
          return item.entryId == operation.entryId;
        }
        if (operation.type == PendingVaultOperationType.setEntry) {
          return item.type == PendingVaultOperationType.setEntry &&
              item.entryId == operation.entryId;
        }
        return false;
      });
      compacted.add(operation);
    }
    return compacted;
  }

  String _metaKey(String uid) => 'vault_cache_meta_$uid';
  String _foldersKey(String uid) => 'vault_cache_folders_$uid';
  String _entriesKey(String uid) => 'vault_cache_entries_$uid';
  String _pendingKey(String uid) => 'vault_pending_ops_$uid';
}

enum PendingVaultOperationType {
  setMeta,
  setFolder,
  deleteFolder,
  setEntry,
  deleteEntry,
}

class PendingVaultOperation {
  const PendingVaultOperation({
    required this.id,
    required this.type,
    required this.createdAt,
    this.folderId,
    this.entryId,
    this.payload,
  });

  final String id;
  final PendingVaultOperationType type;
  final DateTime createdAt;
  final String? folderId;
  final String? entryId;
  final Map<String, dynamic>? payload;

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'createdAt': createdAt.toIso8601String(),
    'folderId': folderId,
    'entryId': entryId,
    'payload': payload,
  };

  factory PendingVaultOperation.fromMap(Map<dynamic, dynamic> map) {
    final typeName = map['type'] as String? ?? '';
    return PendingVaultOperation(
      id: map['id'] as String,
      type: PendingVaultOperationType.values.firstWhere(
        (type) => type.name == typeName,
      ),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      folderId: map['folderId'] as String?,
      entryId: map['entryId'] as String?,
      payload: map['payload'] == null
          ? null
          : Map<String, dynamic>.from(map['payload'] as Map),
    );
  }
}
