import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../providers.dart';
import '../widgets/note_form_sheet.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});
  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String? _filterTagId;

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesStreamProvider);
    final tagsAsync = ref.watch(tagsStreamProvider);
    final mappingsAsync = ref.watch(noteTagsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: tagsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (tags) {
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _filterTagId == null,
                        onSelected: (_) =>
                            setState(() => _filterTagId = null),
                      ),
                    ),
                    for (final t in tags)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 6, 0, 6),
                        child: ChoiceChip(
                          label: Text(t.name),
                          selected: _filterTagId == t.id,
                          onSelected: (sel) => setState(
                              () => _filterTagId = sel ? t.id : null),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: notesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (notes) {
                final mappings =
                    mappingsAsync.value ?? const <NoteTag>[];
                final tagsForNote = <String, List<String>>{};
                for (final m in mappings) {
                  tagsForNote
                      .putIfAbsent(m.noteId, () => [])
                      .add(m.tagId);
                }
                final filtered = _filterTagId == null
                    ? notes
                    : notes
                        .where((n) =>
                            (tagsForNote[n.id] ?? const [])
                                .contains(_filterTagId))
                        .toList();
                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No notes here. Tap + to add one.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final tagsById = {
                  for (final t in (tagsAsync.value ?? const <Tag>[]))
                    t.id: t,
                };
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _NoteTile(
                    note: filtered[i],
                    tags: [
                      for (final id in (tagsForNote[filtered[i].id] ?? const []))
                        if (tagsById[id] != null) tagsById[id]!,
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Note'),
        onPressed: () => showNoteFormSheet(context),
      ),
    );
  }
}

class _NoteTile extends ConsumerWidget {
  const _NoteTile({required this.note, required this.tags});
  final Note note;
  final List<Tag> tags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        onTap: () => _openViewer(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title?.isNotEmpty == true
                          ? note.title!
                          : _firstLine(note.contentMd),
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(DateFormat.MMMd().format(note.occurredAt),
                      style: Theme.of(context).textTheme.bodySmall),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      switch (v) {
                        case 'edit':
                          showNoteFormSheet(context, existing: note);
                        case 'delete':
                          await ref
                              .read(notesRepositoryProvider)
                              .deleteNote(note.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              if (note.title?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  _firstLine(note.contentMd),
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final t in tags)
                      Chip(
                        label: Text(t.name),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openViewer(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _NoteViewer(note: note, tags: tags),
    ));
  }

  String _firstLine(String md) {
    final lines = md.split('\n').where((l) => l.trim().isNotEmpty);
    return lines.isEmpty ? '' : lines.first;
  }
}

class _NoteViewer extends StatelessWidget {
  const _NoteViewer({required this.note, required this.tags});
  final Note note;
  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(note.title?.isNotEmpty == true ? note.title! : 'Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).pop();
              showNoteFormSheet(context, existing: note);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            DateFormat.yMMMMd().format(note.occurredAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [for (final t in tags) Chip(label: Text(t.name))],
            ),
          ],
          const SizedBox(height: 16),
          MarkdownBody(data: note.contentMd, selectable: true),
        ],
      ),
    );
  }
}
