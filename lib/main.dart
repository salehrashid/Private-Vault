import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'app/password_manager_app.dart';
import 'firebase/firebase_bootstrap.dart';
import 'platform_window.dart'
    if (dart.library.io) 'platform_window_io.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  await initializeDesktopWindow();
  runApp(
    const ProviderScope(
      child: ShorebirdUpdateGate(
        child: PasswordManagerApp(),
      ),
    ),
  );
}

class ShorebirdUpdateGate extends StatefulWidget {
  const ShorebirdUpdateGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<ShorebirdUpdateGate> createState() => _ShorebirdUpdateGateState();
}

class _ShorebirdUpdateGateState extends State<ShorebirdUpdateGate> {
  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final updater = ShorebirdUpdater();
    final status = await updater.checkForUpdate();
    if (status == UpdateStatus.outdated) {
      await updater.update();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
