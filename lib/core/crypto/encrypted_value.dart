class EncryptedValue {
  const EncryptedValue(this.value);

  final String value;

  Map<String, dynamic> toMap() => {'value': value};

  factory EncryptedValue.fromMap(Map<String, dynamic> map) {
    return EncryptedValue(map['value'] as String? ?? '');
  }
}
