import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/password_entry.dart';
import '../controllers/vault_providers.dart';

class PasswordList extends ConsumerWidget {
  const PasswordList({super.key, required this.folderId});

  final String folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(folderEntriesProvider(folderId));
    final selected = ref.watch(selectedEntryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Passwordsss'),
        actions: [
          IconButton(
            tooltip: 'New entry',
            onPressed: () => ref.read(selectedEntryProvider.notifier).state =
                _newEntry(folderId),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: entries.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No passwords in this folder'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final entry = items[index];
              return ListTile(
                selected: selected?.id == entry.id,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                leading: CircleAvatar(
                  child: Text(
                    entry.title.isEmpty
                        ? '?'
                        : entry.title.characters.first.toUpperCase(),
                  ),
                ),
                title: Text(
                  entry.title.isEmpty ? 'Untitled entry' : entry.title,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(entry.username, overflow: TextOverflow.ellipsis),
                onTap: () =>
                    ref.read(selectedEntryProvider.notifier).state = entry,
              );
            },
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemCount: items.length,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
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
