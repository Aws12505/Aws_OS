import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/tokens.dart';
import '../../../../shared/utils/date_preset.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../../../shared/widgets/date_time_picker.dart';
import '../note_filter.dart';
import '../providers.dart';

/// Resolved display color for a tag — its stored color, or the notes accent.
Color tagColor(Tag t) => t.color != null ? Color(t.color!) : DomainColors.notes;

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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Filter notes',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
                    const _SectionLabel('TAGS'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in tags)
                          AppChip(
                            label: t.name,
                            color: tagColor(t),
                            selected: filter.tagIds.contains(t.id),
                            onTap: () => update(filter.toggleTag(t.id)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  const _SectionLabel('DATE'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in DatePreset.values)
                        if (p != DatePreset.custom)
                          AppChip(
                            label: p.label,
                            color: DomainColors.notes,
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
                  _CustomDateRow(filter: filter, onUpdate: update),
                  const SizedBox(height: 20),

                  const _SectionLabel('OPTIONS'),
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

class _CustomDateRow extends StatelessWidget {
  const _CustomDateRow({required this.filter, required this.onUpdate});
  final NoteFilter filter;
  final void Function(NoteFilter) onUpdate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat.MMMd();
    final isCustom = filter.datePreset == DatePreset.custom;

    Future<void> pickRange() async {
      final from = await pickDate(
        context,
        initial: filter.customFrom ?? DateTime.now(),
      );
      if (from == null || !context.mounted) return;
      final to = await pickDate(
        context,
        initial: filter.customTo ?? from,
        firstDate: from,
      );
      if (to == null) return;
      onUpdate(
        filter.copyWith(
          datePreset: DatePreset.custom,
          customFrom: from,
          customTo: to,
        ),
      );
    }

    return Row(
      children: [
        AppChip(
          label: isCustom && filter.customFrom != null
              ? '${fmt.format(filter.customFrom!)} – ${fmt.format(filter.customTo ?? filter.customFrom!)}'
              : 'Custom range…',
          icon: Icons.date_range_rounded,
          color: DomainColors.notes,
          selected: isCustom,
          onTap: pickRange,
        ),
        if (isCustom) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onUpdate(
              filter.copyWith(
                datePreset: DatePreset.all,
                customFrom: null,
                customTo: null,
              ),
            ),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}
