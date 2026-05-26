import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_messages.dart';
import '../../domain/password_entry.dart';
import '../controllers/vault_providers.dart';
import 'delete_entry_helper.dart';

class PasswordList extends ConsumerWidget {
  const PasswordList({
    super.key,
    required this.folderId,
    this.showAppBar = true,
  });

  final String folderId;
  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(folderEntriesProvider(folderId));
    final selected = ref.watch(selectedEntryProvider);
    final hiddenEntries = ref.watch(hiddenEntriesProvider);

    final body = entries.when(
      data: (items) {
        final visibleItems = items.where((e) => !hiddenEntries.contains(e.id)).toList();
        if (visibleItems.isEmpty) {
          return const Center(child: Text('No passwords in this folder'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) {
            final entry = visibleItems[index];
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
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: entry.username.isNotEmpty 
                  ? Text(entry.username, overflow: TextOverflow.ellipsis)
                  : null,
              onTap: () =>
                  ref.read(selectedEntryProvider.notifier).state = entry,
              onLongPress: () => deleteEntryWithUndo(context, ref, entry),
            );
          },
          separatorBuilder: (context, index) => const SizedBox(height: 6),
          itemCount: visibleItems.length,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(userFacingErrorMessage(error))),
    );

    if (!showAppBar) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Passwords'),
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        tooltip: 'New entry',
        onPressed: () => ref.read(selectedEntryProvider.notifier).state =
            _newEntry(folderId),
        child: const Icon(Icons.add),
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
