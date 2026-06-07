import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'internet_connection_service.dart';

const noInternetMessage = 'No internet connection.';

final internetConnectionServiceProvider = Provider<InternetConnectionService>((
  ref,
) {
  final service = InternetConnectionService();
  ref.onDispose(service.dispose);
  return service;
});

final internetConnectionProvider = StreamProvider<bool>((ref) {
  return ref.watch(internetConnectionServiceProvider).status;
});

Future<void> requireInternet(Ref ref) async {
  final online = await ref.read(internetConnectionServiceProvider).checkNow();
  if (!online) {
    throw const OfflineException();
  }
}

class OfflineException implements Exception {
  const OfflineException();
}
