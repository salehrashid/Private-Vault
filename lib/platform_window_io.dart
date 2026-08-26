import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initializeDesktopWindow() async {
  if (!Platform.isWindows && !Platform.isLinux) {
    return;
  }

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(900, 600),
    minimumSize: Size(900, 600),
    center: true,
    fullScreen: false,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.maximize();
  });
}
