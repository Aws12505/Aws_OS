import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_filter_bar.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/hero_title.dart';
import '../../../../shared/widgets/stagger.dart';
import '../note_filter.dart';
import '../providers.dart';
import '../widgets/note_filter_sheet.dart';
import '../widgets/note_form_sheet.dart';
import '../../../../shared/widgets/app_card.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});
  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(noteFilterProvider);
    final notesAsync = ref.watch(notesStreamProvider);
    final tagsAsync = ref.watch(tagsStreamProvider);
    final mappingsAsync = ref.watch(noteTagsStreamProvider);

    return AppScaffold(
      body: Column(
        children: [
          SectionHeader(
            title: 'Notes',
            status: switch (notesAsync.valueOrNull?.length) {
              null => null,
              0 => 'Nothing captured yet',
              1 => '1 note',
              final n => '$n notes',
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search notes',
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear the search',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          const _FilterBar(),
          Expanded(
            child: notesAsync.when(
              loading: () => const AppLoading(message: 'Loading your notes'),
              error: (e, _) => AppErrorView(error: e),
              data: (notes) {
                final mappings = mappingsAsync.value ?? const <NoteTag>[];
                final tagsForNote = <String, List<String>>{};
                for (final m in mappings) {
                  tagsForNote.putIfAbsent(m.noteId, () => []).add(m.tagId);
                }

                final filtered =
                    notes.where((n) {
                        if (!filter.matches(n, tagsForNote[n.id] ?? const [])) {
                          return false;
                        }
                        if (_query.isEmpty) return true;
                        return (n.title ?? '').toLowerCase().contains(_query) ||
                            n.contentMd.toLowerCase().contains(_query);
                      }).toList()
                      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

                if (filtered.isEmpty) {
                  final searching = _query.isNotEmpty || !filter.isDefault;
                  return AppEmptyState(
                    icon: searching
                        ? Icons.search_off_rounded
                        : Icons.sticky_note_2_rounded,
                    title: searching ? 'No matching notes' : 'No notes yet',
                    message: searching
                        ? 'Nothing matches that search and those filters. '
                              'Try widening one of them.'
                        : 'Capture a thought, an idea, or a journal entry.',
                    accent: context.sem.notes.base,
                    action: searching
                        ? null
                        : FilledButton.icon(
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Write a note'),
                            onPressed: () => showNoteFormSheet(context),
                          ),
                  );
                }

                final tagsById = {
                  for (final t in (tagsAsync.value ?? const <Tag>[])) t.id: t,
                };
                return ListView.separated(
                  padding: const EdgeInsets.only(
                    bottom: AppInsets.listBottom,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const AppRule(indent: AppSpacing.xl),
                  itemBuilder: (_, i) => StaggeredEntry(
                    index: i,
                    child: _NoteTile(
                      note: filtered[i],
                      tags: [
                      for (final id
                          in (tagsForNote[filtered[i].id] ?? const []))
                        if (tagsById[id] != null) tagsById[id]!,
                      ],
                    ),
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

// ── filter bar ───────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(noteFilterProvider);
    return AppFilterBar(
      activeCount: filter.activeCount,
      color: context.sem.notes.base,
      onOpenFilters: () => showNoteFilterSheet(context),
      onClear: filter.isDefault
          ? null
          : () => ref.read(noteFilterProvider.notifier).state =
                const NoteFilter(),
    );
  }
}

// ── note tile ────────────────────────────────────────────────────────────────

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
    // A note is a row, not a card: the accent bar on the left already marks
    // where one ends and the next begins.
    return PressableSurface(
      onTap: () => _openViewer(context),
      semanticsLabel: 'Open note',
      child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        14,
        AppSpacing.sm,
        14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: tags.isNotEmpty ? 80 : 44,
            decoration: BoxDecoration(
              color: context.sem.notes.base,
              borderRadius: BorderRadius.circular(AppRadius.xs),
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
                      child: HeroTitle(
                        tag: 'note-${note.id}',
                        text: title,
                        style: tt.titleSmall!.weight(FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat.MMMd().format(note.occurredAt),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
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
                if (preview != null && preview.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: tagColor(context, t).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            t.name,
                            style: tt.labelSmall?.copyWith(
                              color: tagColor(context, t),
                            ).weight(FontWeight.w600),
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
    );
  }

  void _openViewer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _NoteViewer(note: note, tags: tags),
      ),
    );
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
    return AppScaffold(
      appBar: AppBar(
        title: HeroTitle(
          tag: 'note-${note.id}',
          text: note.title?.isNotEmpty == true ? note.title! : 'Note',
          style: Theme.of(context).appBarTheme.titleTextStyle ??
              tt.titleLarge!,
        ),
        actions: [
          IconButton(
            tooltip: 'Edit this note',
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
              Icon(Icons.event_rounded, size: 14, color: cs.onSurfaceVariant),
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
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tagColor(context, t).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      t.name,
                      style: tt.labelSmall?.copyWith(
                        color: tagColor(context, t),
                      ).weight(FontWeight.w600),
                    ),
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
