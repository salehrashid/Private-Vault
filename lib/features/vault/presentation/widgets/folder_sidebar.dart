import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_messages.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../domain/vault_folder.dart';
import '../controllers/vault_providers.dart';

class FolderSidebar extends ConsumerWidget {
  const FolderSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(vaultFoldersProvider);
    final selected = ref.watch(selectedFolderIdProvider);

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
                if (items.isNotEmpty && selected == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(selectedFolderIdProvider.notifier).state =
                        items.first.id;
                  });
                }
                if (items.isEmpty) {
                  return const Center(child: Text('No folders yet'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  itemBuilder: (context, index) {
                    final folder = items[index];
                    return _FolderTile(
                      folder: folder,
                      selected: selected == folder.id,
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 4),
                  itemCount: items.length,
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
          if (value == 'rename') {
            await showFolderDialog(context, ref, folder: folder);
          }
          if (value == 'delete') {
            await ref
                .read(vaultControllerProvider.notifier)
                .deleteFolder(folder.id);
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
  final controller = TextEditingController(text: folder?.name ?? '');
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(folder == null ? 'New folder' : 'Rename folder'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Folder name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || name.isEmpty) {
    return;
  }
  final vault = ref.read(vaultControllerProvider.notifier);
  folder == null
      ? await vault.createFolder(name)
      : await vault.renameFolder(folder.id, name);
}
