import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/responsive_breakpoints.dart';
import '../../domain/password_entry.dart';
import '../controllers/vault_providers.dart';
import '../widgets/entry_editor.dart';
import '../widgets/folder_sidebar.dart';
import '../widgets/password_list.dart';

class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(vaultControllerProvider, (_, next) {
      final error = next.error;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    });

    final width = MediaQuery.sizeOf(context).width;
    return width >= ResponsiveBreakpoints.desktop
        ? const _DesktopVault()
        : const _MobileVault();
  }
}

class _DesktopVault extends ConsumerWidget {
  const _DesktopVault();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFolderId = ref.watch(selectedFolderIdProvider);
    final selectedEntry = ref.watch(selectedEntryProvider);

    return Scaffold(
      body: Row(
        children: [
          const SizedBox(width: 280, child: FolderSidebar()),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 360,
            child: selectedFolderId == null
                ? const _EmptyPane(
                    icon: Icons.folder_open,
                    text: 'Select a folder',
                  )
                : PasswordList(folderId: selectedFolderId),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: selectedFolderId == null
                ? const _EmptyPane(
                    icon: Icons.shield_outlined,
                    text: 'Encrypted vault ready',
                  )
                : EntryEditor(folderId: selectedFolderId, entry: selectedEntry),
          ),
        ],
      ),
    );
  }
}

class _MobileVault extends ConsumerWidget {
  const _MobileVault();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFolderId = ref.watch(selectedFolderIdProvider);
    final selectedEntry = ref.watch(selectedEntryProvider);

    if (selectedEntry != null && selectedFolderId != null) {
      return EntryEditor(folderId: selectedFolderId, entry: selectedEntry);
    }

    if (selectedFolderId != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Folders',
            onPressed: () =>
                ref.read(selectedFolderIdProvider.notifier).state = null,
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Passwords'),
          actions: [
            IconButton(
              tooltip: 'New entry',
              onPressed: () => ref.read(selectedEntryProvider.notifier).state =
                  _newEntry(selectedFolderId),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: PasswordList(folderId: selectedFolderId),
      );
    }

    return const Scaffold(body: FolderSidebar());
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(text, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

PasswordEntry _newEntry(String folderId) {
  final now = DateTime.now().toUtc();
  return PasswordEntry(
    id: '',
    folderId: folderId,
    title: '',
    username: '',
    password: '',
    createdAt: now,
    updatedAt: now,
  );
}
