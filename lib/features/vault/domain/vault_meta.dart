import '../../../core/crypto/vault_crypto_service.dart';

class VaultMeta {
  const VaultMeta({required this.kdfConfig, required this.verifier});

  final VaultKdfConfig kdfConfig;
  final String verifier;
}
