class PasswordEntry {
  const PasswordEntry({
    required this.id,
    required this.folderId,
    required this.title,
    required this.username,
    required this.password,
    required this.createdAt,
    required this.updatedAt,
    this.url,
    this.notes,
  });

  final String id;
  final String folderId;
  final String title;
  final String username;
  final String password;
  final String? url;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  PasswordEntry copyWith({
    String? id,
    String? folderId,
    String? title,
    String? username,
    String? password,
    String? url,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PasswordEntry(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
