import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/tokens.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../providers.dart';
import '../widgets/note_form_sheet.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});
  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String? _filterTagId;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesStreamProvider);
    final tagsAsync = ref.watch(tagsStreamProvider);
    final mappingsAsync = ref.watch(noteTagsStreamProvider);

    return AppScaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: DomainColors.notes,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Note'),
        onPressed: () => showNoteFormSheet(context),
      ),
      body: Column(
        children: [
          const SectionHeader(kicker: 'Capture', title: 'Notes'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: (v) =>
                  setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search notes',
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: tagsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (tags) {
                if (tags.isEmpty) return const SizedBox.shrink();
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: AppChip(
                        label: 'All',
                        color: DomainColors.notes,
                        selected: _filterTagId == null,
                        onTap: () => setState(() => _filterTagId = null),
                      ),
                    ),
                    for (final t in tags)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: AppChip(
                          label: t.name,
                          color: DomainColors.notes,
                          selected: _filterTagId == t.id,
                          onTap: () => setState(() => _filterTagId =
                              _filterTagId == t.id ? null : t.id),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: notesAsync.when(
              loading: () => const AppLoading(),
              error: (e, _) => AppErrorView(error: e),
              data: (notes) {
                final mappings = mappingsAsync.value ?? const <NoteTag>[];
                final tagsForNote = <String, List<String>>{};
                for (final m in mappings) {
                  tagsForNote.putIfAbsent(m.noteId, () => []).add(m.tagId);
                }
                var filtered = _filterTagId == null
                    ? notes
                    : notes
                        .where((n) => (tagsForNote[n.id] ?? const [])
                            .contains(_filterTagId))
                        .toList();
                if (_query.isNotEmpty) {
                  filtered = filtered
                      .where((n) =>
                          (n.title ?? '').toLowerCase().contains(_query) ||
                          n.contentMd.toLowerCase().contains(_query))
                      .toList();
                }
                filtered = filtered.toList()
                  ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

                if (filtered.isEmpty) {
                  final searching = _query.isNotEmpty || _filterTagId != null;
                  return AppEmptyState(
                    icon: searching
                        ? Icons.search_off_rounded
                        : Icons.sticky_note_2_rounded,
                    title: searching ? 'No matching notes' : 'No notes yet',
                    message: searching
                        ? 'Try a different search or tag.'
                        : 'Capture a thought, idea, or journal entry.',
                    accent: DomainColors.notes,
                    action: searching
                        ? null
                        : FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: DomainColors.notes,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Write a note'),
                            onPressed: () => showNoteFormSheet(context),
                          ),
                  );
                }

                final tagsById = {
                  for (final t in (tagsAsync.value ?? const <Tag>[])) t.id: t,
                };
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 110),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _NoteTile(
                    note: filtered[i],
                    tags: [
                      for (final id
                          in (tagsForNote[filtered[i].id] ?? const []))
                        if (tagsById[id] != null) tagsById[id]!,
                    ],
                  ),
                );
              },
            ),
          ),
        ],
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
    final preview =
        note.title?.isNotEmpty == true ? _firstLine(note.contentMd) : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.72),
        borderRadius: BorderRadius.circular(AppRadius.xl),
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
                    color: DomainColors.notes,
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
                              style: tt.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat.MMMd().format(note.occurredAt),
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
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
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
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
                                  color: DomainColors.notes
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  t.name,
                                  style: tt.labelSmall?.copyWith(
                                    color: DomainColors.notes,
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
    return lines.isEmpty ? '' : lines.first.replaceAll(RegExp(r'^#+\s*'), '');
  }
}

class _NoteViewer extends StatelessWidget {
  const _NoteViewer({required this.note, required this.tags});
  final Note note;
  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(note.title?.isNotEmpty == true ? note.title! : 'Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () {
              Navigator.of(context).pop();
              showNoteFormSheet(context, existing: note);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Icon(Icons.event_rounded,
                  size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                DateFormat.yMMMMEEEEd().format(note.occurredAt),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DomainColors.notes.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(t.name,
                        style: tt.labelSmall?.copyWith(
                          color: DomainColors.notes,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
              ],
            ),
          ],
          const Divider(height: 32),
          MarkdownBody(data: note.contentMd, selectable: true),
        ],
      ),
    );
  }
}
