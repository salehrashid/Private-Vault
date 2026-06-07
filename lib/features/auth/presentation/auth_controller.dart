import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/network_providers.dart';
import '../data/firedart_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FiredartAuthRepository();
});

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authState();
});

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

final authSessionMessageProvider = StateProvider<String?>((ref) => null);

final authSessionMonitorProvider = Provider<void>((ref) {
  Timer? timer;
  var verifying = false;
  var invalidSessionHandled = false;

  Future<void> verify() async {
    final auth = ref.read(authStateProvider).valueOrNull;
    final online = ref.read(internetConnectionProvider).valueOrNull;
    if (auth == null || online == false || verifying || invalidSessionHandled) {
      return;
    }

    verifying = true;
    try {
      await ref.read(authRepositoryProvider).verifyCurrentUser();
    } on AppException catch (error) {
      if (error.message ==
          'Your account is no longer available. Please sign in again.') {
        invalidSessionHandled = true;
        timer?.cancel();
        timer = null;
        ref.invalidate(authStateProvider);
        ref.read(authSessionMessageProvider.notifier).state = error.message;
      }
    } finally {
      verifying = false;
    }
  }

  ref.listen(authStateProvider, (_, next) {
    if (next.valueOrNull == null) {
      timer?.cancel();
      timer = null;
      return;
    }
    invalidSessionHandled = false;
    timer ??= Timer.periodic(const Duration(seconds: 10), (_) => verify());
    unawaited(verify());
  }, fireImmediately: true);

  ref.listen(internetConnectionProvider, (_, next) {
    if (next.valueOrNull == true) {
      unawaited(verify());
    }
  });

  ref.onDispose(() => timer?.cancel());
});

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await requireInternet(ref);
      await ref.read(authRepositoryProvider).signIn(email, password);
    });
  }

  Future<void> signUp(String email, String password) async {
    if (password.length < 8) {
      state = const AsyncError(
        AppException('Use at least 8 characters for the account password.'),
        StackTrace.empty,
      );
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await requireInternet(ref);
      await ref.read(authRepositoryProvider).signUp(email, password);
    });
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await requireInternet(ref);
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
    });
  }
}
