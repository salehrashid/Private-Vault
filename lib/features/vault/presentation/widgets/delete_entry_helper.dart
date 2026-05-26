import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/password_entry.dart';
import '../controllers/vault_providers.dart';
import 'undo_snackbar.dart';

Future<void> deleteEntryWithUndo(BuildContext context, WidgetRef ref, PasswordEntry entry) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Entry?'),
      content: Text('Are you sure you want to delete "${entry.title}"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;
  if (!context.mounted) return;

  final hiddenEntriesNotifier = ref.read(hiddenEntriesProvider.notifier);
  final vaultController = ref.read(vaultControllerProvider.notifier);

  hiddenEntriesNotifier.update((state) => {...state, entry.id});
  
  if (ref.read(selectedEntryProvider)?.id == entry.id) {
    ref.read(selectedEntryProvider.notifier).state = null;
  }

  final scaffoldMessenger = ScaffoldMessenger.of(context);
  scaffoldMessenger.hideCurrentSnackBar();

  bool isUndo = false;
  final snackBar = buildUndoSnackBar(
    message: 'Entry deleted',
    onUndo: () {
      isUndo = true;
    },
  );

  final controller = scaffoldMessenger.showSnackBar(snackBar);
  
  Future.delayed(const Duration(seconds: 4), () {
    try {
      controller.close();
    } catch (_) {}
  });

  final reason = await controller.closed;

  if (isUndo || reason == SnackBarClosedReason.action) {
    hiddenEntriesNotifier.update((state) {
      final newState = Set<String>.from(state);
      newState.remove(entry.id);
      return newState;
    });
  } else {
    await vaultController.deleteEntry(entry);
    hiddenEntriesNotifier.update((state) {
      final newState = Set<String>.from(state);
      newState.remove(entry.id);
      return newState;
    });
  }
}
