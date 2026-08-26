import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/app_theme.dart';
import '../../../../shared/utils/date_preset.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../../../shared/widgets/date_range_row.dart';
import '../../../../shared/widgets/section_header.dart';
import '../note_filter.dart';
import '../providers.dart';

/// Display color for a tag: its own stored color, or the notes accent.
Color tagColor(BuildContext context, Tag t) =>
    t.color != null ? Color(t.color!) : context.sem.notes.base;

void showNoteFilterSheet(BuildContext context) {
  showAppModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _NoteFilterSheet(),
  );
}

class _NoteFilterSheet extends ConsumerWidget {
  const _NoteFilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filter = ref.watch(noteFilterProvider);
    final tags = ref.watch(tagsStreamProvider).value ?? const <Tag>[];

    void update(NoteFilter f) =>
        ref.read(noteFilterProvider.notifier).state = f;

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Filter notes',
                    style: tt.titleMedium,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: filter.isDefault
                        ? null
                        : () => update(const NoteFilter()),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  if (tags.isNotEmpty) ...[
                    const SectionLabel('Tags'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in tags)
                          AppChip(
                            label: t.name,
                            color: tagColor(context, t),
                            selected: filter.tagIds.contains(t.id),
                            onTap: () => update(filter.toggleTag(t.id)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  const SectionLabel('Date'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in DatePreset.values)
                        if (p != DatePreset.custom)
                          AppChip(
                            label: p.label,
                            color: context.sem.notes.base,
                            selected: filter.datePreset == p,
                            onTap: () => update(
                              filter.copyWith(
                                datePreset: p,
                                customFrom: null,
                                customTo: null,
                              ),
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DateRangeRow(
                    from: filter.customFrom,
                    to: filter.customTo,
                    selected: filter.datePreset == DatePreset.custom,
                    color: context.sem.notes.base,
                    onPicked: (from, to) => update(
                      filter.copyWith(
                        datePreset: DatePreset.custom,
                        customFrom: from,
                        customTo: to,
                      ),
                    ),
                    onCleared: () => update(
                      filter.copyWith(
                        datePreset: DatePreset.all,
                        customFrom: null,
                        customTo: null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const SectionLabel('Options'),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Untagged only'),
                    subtitle: const Text('Notes that have no tags'),
                    value: filter.untaggedOnly,
                    onChanged: (v) => update(
                      filter.copyWith(
                        untaggedOnly: v,
                        tagIds: v ? <String>{} : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

