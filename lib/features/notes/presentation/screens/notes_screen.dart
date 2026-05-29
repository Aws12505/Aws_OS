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

    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CAPTURE',
                    style: tt.labelSmall?.copyWith(
                      color: const Color(0xFF8B5CF6),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    )),
                const SizedBox(height: 2),
                Text('Notes',
                    style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    )),
              ],
            ),
          ),
          SizedBox(
            height: 52,
            child: tagsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (tags) {
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _filterTagId == null,
                        onSelected: (_) =>
                            setState(() => _filterTagId = null),
                      ),
                    ),
                    for (final t in tags)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
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
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.sticky_note_2_rounded,
                                size: 40, color: Color(0xFF8B5CF6)),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No notes here',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to write your first note.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = note.title?.isNotEmpty == true
        ? note.title!
        : _firstLine(note.contentMd);
    final preview = note.title?.isNotEmpty == true
        ? _firstLine(note.contentMd)
        : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        onTap: () => _openViewer(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: tags.isNotEmpty ? 80 : 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat.MMMd().format(note.occurredAt),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert_rounded,
                              size: 18, color: cs.onSurfaceVariant),
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
                            PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ],
                    ),
                    if (preview != null && preview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                t.name,
                                style: tt.labelSmall?.copyWith(
                                  color: const Color(0xFF8B5CF6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
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
