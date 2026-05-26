import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/password_entry.dart';
import '../../domain/vault_folder.dart';
import '../controllers/vault_providers.dart';
import 'delete_entry_helper.dart';

class EntryEditor extends ConsumerStatefulWidget {
  const EntryEditor({super.key, required this.folderId, required this.entry});

  final String folderId;
  final PasswordEntry? entry;

  @override
  ConsumerState<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends ConsumerState<EntryEditor> {
  final _title = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _url = TextEditingController();
  final _notes = TextEditingController();
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _load(widget.entry);
  }

  @override
  void didUpdateWidget(covariant EntryEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry?.id != widget.entry?.id) {
      _load(widget.entry);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _username.dispose();
    _password.dispose();
    _url.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final busy = ref.watch(vaultControllerProvider).isLoading;
    final folders = ref.watch(vaultFoldersProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        leading: MediaQuery.sizeOf(context).width < 900
            ? IconButton(
                tooltip: 'Back',
                onPressed: () =>
                    ref.read(selectedEntryProvider.notifier).state = null,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Text(
          entry == null || entry.id.isEmpty ? 'New entry' : 'Edit entry',
        ),
        actions: [
          if (entry != null && entry.id.isNotEmpty)
            IconButton(
              tooltip: 'Delete',
              onPressed: busy ? null : () => deleteEntryWithUndo(context, ref, entry),
              icon: const Icon(Icons.delete_outline),
            ),
          IconButton(
            tooltip: 'Save',
            onPressed: busy ? null : _save,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: entry == null
          ? const Center(child: Text('Select an entry or create a new one'))
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _username,
                  decoration: const InputDecoration(
                    labelText: 'Username or email',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: Wrap(
                      children: [
                        IconButton(
                          tooltip: _showPassword ? 'Hide' : 'Show',
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy',
                          onPressed: _password.text.isEmpty
                              ? null
                              : () => Clipboard.setData(
                                  ClipboardData(text: _password.text),
                                ),
                          icon: const Icon(Icons.copy),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _url,
                  decoration: const InputDecoration(labelText: 'URL'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 16),
                if (entry.id.isNotEmpty && folders.length > 1)
                  _MoveEntryMenu(entry: entry, folders: folders),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: busy ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save entry'),
                ),
              ],
            ),
    );
  }

  void _load(PasswordEntry? entry) {
    _title.text = entry?.title ?? '';
    _username.text = entry?.username ?? '';
    _password.text = entry?.password ?? '';
    _url.text = entry?.url ?? '';
    _notes.text = entry?.notes ?? '';
  }

  Future<void> _save() async {
    final base = widget.entry;
    if (base == null || _title.text.trim().isEmpty) {
      return;
    }
    
    final isNew = base.id.isEmpty;
    final entry = base.copyWith(
      folderId: widget.folderId,
      title: _title.text,
      username: _username.text,
      password: _password.text,
      url: _url.text.trim().isEmpty ? null : _url.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text,
    );
    await ref.read(vaultControllerProvider.notifier).saveEntry(entry);
    
    if (!mounted) return;
    
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    if (isNew || isMobile) {
      ref.read(selectedEntryProvider.notifier).state = null;
    } else {
      ref.read(selectedEntryProvider.notifier).state = entry;
    }
  }

}

class _MoveEntryMenu extends ConsumerWidget {
  const _MoveEntryMenu({required this.entry, required this.folders});

  final PasswordEntry entry;
  final List<VaultFolder> folders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButtonFormField<String>(
      initialValue: entry.folderId,
      decoration: const InputDecoration(labelText: 'Folder'),
      items: folders
          .map(
            (folder) =>
                DropdownMenuItem(value: folder.id, child: Text(folder.name)),
          )
          .toList(),
      onChanged: (folderId) async {
        if (folderId == null || folderId == entry.folderId) {
          return;
        }
        await ref
            .read(vaultControllerProvider.notifier)
            .moveEntry(entry, folderId);
        ref.read(selectedFolderIdProvider.notifier).state = folderId;
        ref.read(selectedEntryProvider.notifier).state = null;
      },
    );
  }
}
