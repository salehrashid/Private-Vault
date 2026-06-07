import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/responsive_breakpoints.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/network/network_providers.dart';
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
        ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(error))));
      }
    });
    ref.listen(vaultRefreshControllerProvider, (_, next) {
      final error = next.error;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(error))));
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
    final canExit = selectedFolderId == null && selectedEntry == null;

    return PopScope<void>(
      canPop: canExit,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        if (selectedEntry != null) {
          ref.read(selectedEntryProvider.notifier).state = null;
          return;
        }
        if (selectedFolderId != null) {
          ref.read(selectedFolderIdProvider.notifier).state = null;
        }
      },
      child: _MobileVaultBody(
        selectedFolderId: selectedFolderId,
        selectedEntry: selectedEntry,
      ),
    );
  }
}

class _MobileVaultBody extends ConsumerWidget {
  const _MobileVaultBody({
    required this.selectedFolderId,
    required this.selectedEntry,
  });

  final String? selectedFolderId;
  final PasswordEntry? selectedEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderId = selectedFolderId;
    final refreshBusy = ref.watch(vaultRefreshControllerProvider).isLoading;
    final online = ref.watch(internetConnectionProvider).valueOrNull != false;

    if (selectedEntry != null && folderId != null) {
      return EntryEditor(folderId: folderId, entry: selectedEntry);
    }

    if (folderId != null) {
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
              tooltip: 'Refresh',
              onPressed: refreshBusy || !online
                  ? null
                  : () => ref
                        .read(vaultRefreshControllerProvider.notifier)
                        .refresh(),
              icon: refreshBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        body: PasswordList(folderId: folderId, showAppBar: false),
        floatingActionButton: FloatingActionButton(
          tooltip: 'New entry',
          onPressed: () => ref.read(selectedEntryProvider.notifier).state =
              _newEntry(folderId),
          child: const Icon(Icons.add),
        ),
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
