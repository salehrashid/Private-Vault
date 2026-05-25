import '../../../core/crypto/encrypted_value.dart';
import '../domain/password_entry.dart';
import '../domain/vault_folder.dart';

DateTime _dateFrom(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

class FolderCipherDto {
  const FolderCipherDto({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
  });

  final String id;
  final EncryptedValue name;
  final String? parentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
    'name': name.toMap(),
    'parentId': parentId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'schemaVersion': 1,
  };

  factory FolderCipherDto.fromMap(String id, Map<String, dynamic> map) {
    return FolderCipherDto(
      id: id,
      name: EncryptedValue.fromMap(Map<String, dynamic>.from(map['name'])),
      parentId: map['parentId'] as String?,
      createdAt: _dateFrom(map['createdAt']),
      updatedAt: _dateFrom(map['updatedAt']),
    );
  }

  VaultFolder toEntity(String clearName) {
    return VaultFolder(
      id: id,
      name: clearName,
      parentId: parentId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class EntryCipherDto {
  const EntryCipherDto({
    required this.id,
    required this.folderId,
    required this.title,
    required this.username,
    required this.password,
    required this.url,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String folderId;
  final EncryptedValue title;
  final EncryptedValue username;
  final EncryptedValue password;
  final EncryptedValue url;
  final EncryptedValue notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
    'folderId': folderId,
    'title': title.toMap(),
    'username': username.toMap(),
    'password': password.toMap(),
    'url': url.toMap(),
    'notes': notes.toMap(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'schemaVersion': 1,
  };

  factory EntryCipherDto.fromMap(String id, Map<String, dynamic> map) {
    return EntryCipherDto(
      id: id,
      folderId: map['folderId'] as String,
      title: EncryptedValue.fromMap(Map<String, dynamic>.from(map['title'])),
      username: EncryptedValue.fromMap(
        Map<String, dynamic>.from(map['username']),
      ),
      password: EncryptedValue.fromMap(
        Map<String, dynamic>.from(map['password']),
      ),
      url: EncryptedValue.fromMap(Map<String, dynamic>.from(map['url'])),
      notes: EncryptedValue.fromMap(Map<String, dynamic>.from(map['notes'])),
      createdAt: _dateFrom(map['createdAt']),
      updatedAt: _dateFrom(map['updatedAt']),
    );
  }

  PasswordEntry toEntity({
    required String title,
    required String username,
    required String password,
    required String url,
    required String notes,
  }) {
    return PasswordEntry(
      id: id,
      folderId: folderId,
      title: title,
      username: username,
      password: password,
      url: url.isEmpty ? null : url,
      notes: notes.isEmpty ? null : notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
