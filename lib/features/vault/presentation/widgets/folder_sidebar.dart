import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_messages.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../../app/responsive_breakpoints.dart';
import '../../domain/vault_folder.dart';
import '../controllers/vault_providers.dart';
import 'undo_snackbar.dart';

class FolderSidebar extends ConsumerWidget {
  const FolderSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(vaultFoldersProvider);
    final selected = ref.watch(selectedFolderIdProvider);
    final hiddenFolders = ref.watch(hiddenFoldersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Private Vault'),
        actions: [
          IconButton(
            tooltip: 'Lock',
            onPressed: () => ref.read(vaultControllerProvider.notifier).lock(),
            icon: const Icon(Icons.lock),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(vaultControllerProvider.notifier).lock();
              await ref.read(authRepositoryProvider).signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: () => showFolderDialog(context, ref),
              icon: const Icon(Icons.create_new_folder),
              label: const Text('New folder'),
            ),
          ),
          Expanded(
            child: folders.when(
              data: (items) {
                final visibleItems = items.where((f) => !hiddenFolders.contains(f.id)).toList();
                final isDesktop = MediaQuery.sizeOf(context).width >=
                    ResponsiveBreakpoints.desktop;
                if (isDesktop && visibleItems.isNotEmpty && selected == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(selectedFolderIdProvider.notifier).state =
                        visibleItems.first.id;
                  });
                }
                if (visibleItems.isEmpty) {
                  return const Center(child: Text('No folders yet'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  itemBuilder: (context, index) {
                    final folder = visibleItems[index];
                    return _FolderTile(
                      folder: folder,
                      selected: selected == folder.id,
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 4),
                  itemCount: visibleItems.length,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text(userFacingErrorMessage(error))),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderTile extends ConsumerWidget {
  const _FolderTile({required this.folder, required this.selected});

  final VaultFolder folder;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: const Icon(Icons.folder_outlined),
      title: Text(folder.name, overflow: TextOverflow.ellipsis),
      onTap: () {
        ref.read(selectedFolderIdProvider.notifier).state = folder.id;
        ref.read(selectedEntryProvider.notifier).state = null;
      },
      trailing: PopupMenuButton<String>(
        tooltip: 'Folder actions',
        onSelected: (value) async {
          switch (value) {
            case 'rename':
              await showFolderDialog(context, ref, folder: folder);
              break;
            case 'delete':
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Folder?'),
                  content: Text('Are you sure you want to delete "${folder.name}" and all its entries?'),
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

              final hiddenFoldersNotifier = ref.read(hiddenFoldersProvider.notifier);
              final vaultController = ref.read(vaultControllerProvider.notifier);

              hiddenFoldersNotifier.update((s) => {...s, folder.id});
              if (ref.read(selectedFolderIdProvider) == folder.id) {
                 ref.read(selectedFolderIdProvider.notifier).state = null;
                 ref.read(selectedEntryProvider.notifier).state = null;
              }

              final scaffoldMessenger = ScaffoldMessenger.of(context);
              scaffoldMessenger.hideCurrentSnackBar();

              bool isUndo = false;
              final snackBar = buildUndoSnackBar(
                message: 'Folder deleted',
                onUndo: () {
                  isUndo = true;
                },
              );

              final controller = scaffoldMessenger.showSnackBar(snackBar);
              
              // Memaksa snackbar tertutup setelah 4 detik 
              // (mencegah bug hover di desktop yang membuat snackbar diam)
              Future.delayed(const Duration(seconds: 4), () {
                try {
                  controller.close();
                } catch (_) {}
              });

              final reason = await controller.closed;

              if (isUndo || reason == SnackBarClosedReason.action) {
                 hiddenFoldersNotifier.update((s) {
                   final newS = Set<String>.from(s);
                   newS.remove(folder.id);
                   return newS;
                 });
              } else {
                 await vaultController.deleteFolder(folder.id);
                 hiddenFoldersNotifier.update((s) {
                   final newS = Set<String>.from(s);
                   newS.remove(folder.id);
                   return newS;
                 });
              }
              break;
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}

Future<void> showFolderDialog(
  BuildContext context,
  WidgetRef ref, {
  VaultFolder? folder,
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (context) => _FolderDialog(folder: folder),
  );
  
  if (name == null || name.isEmpty) {
    return;
  }
  
  final vault = ref.read(vaultControllerProvider.notifier);
  folder == null
      ? await vault.createFolder(name)
      : await vault.renameFolder(folder.id, name);
}

class _FolderDialog extends StatefulWidget {
  const _FolderDialog({this.folder});
  final VaultFolder? folder;

  @override
  State<_FolderDialog> createState() => _FolderDialogState();
}

class _FolderDialogState extends State<_FolderDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.folder?.name ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.folder == null ? 'New folder' : 'Rename folder'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Folder name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
