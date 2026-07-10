import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../../../shared/widgets/date_time_picker.dart';
import '../providers.dart';
import '../task_filter.dart';

void showTaskFilterSheet(BuildContext context) {
  showAppModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const _TaskFilterSheet(),
  );
}

class _TaskFilterSheet extends ConsumerStatefulWidget {
  const _TaskFilterSheet();

  @override
  ConsumerState<_TaskFilterSheet> createState() => _TaskFilterSheetState();
}

class _TaskFilterSheetState extends ConsumerState<_TaskFilterSheet> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filter = ref.watch(taskFilterProvider);
    final categories = ref.watch(taskCategoriesProvider);

    void update(TaskFilter f) =>
        ref.read(taskFilterProvider.notifier).state = f;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
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
            // Handle
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
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text('Filter Tasks',
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        update(const TaskFilter()),
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
                  // ── STATUS ──────────────────────────────────────────
                  _SectionLabel('STATUS'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TaskStatusFilter.values.map((s) {
                      final label = switch (s) {
                        TaskStatusFilter.all => 'All',
                        TaskStatusFilter.active => 'Active',
                        TaskStatusFilter.completed => 'Completed',
                      };
                      return AppChip(
                        label: label,
                        selected: filter.status == s,
                        color: cs.primary,
                        onTap: () => update(filter.copyWith(status: s)),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // ── DUE DATE ─────────────────────────────────────────
                  _SectionLabel('DUE DATE'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TaskDateFilter.values
                        .where((d) => d != TaskDateFilter.custom)
                        .map((d) => AppChip(
                              label: d.label,
                              selected: filter.dateFilter == d,
                              color: const Color(0xFF3B82F6),
                              onTap: () => update(filter.copyWith(
                                dateFilter: d,
                                customRangeStart: null,
                                customRangeEnd: null,
                              )),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  // Custom date range row
                  _CustomDateRow(filter: filter, onUpdate: update),

                  const SizedBox(height: 20),

                  // ── CATEGORY ─────────────────────────────────────────
                  if (categories.isNotEmpty) ...[
                    _SectionLabel('CATEGORY'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppChip(
                          label: 'All',
                          selected: filter.category == null,
                          color: const Color(0xFF8B5CF6),
                          onTap: () =>
                              update(filter.copyWith(category: null)),
                        ),
                        ...categories.map((c) => AppChip(
                              label: c,
                              selected: filter.category == c,
                              color: const Color(0xFF8B5CF6),
                              onTap: () => update(filter.copyWith(category: c)),
                            )),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── OPTIONS ──────────────────────────────────────────
                  _SectionLabel('OPTIONS'),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Recurring tasks only'),
                    subtitle: const Text('Tasks that repeat on a schedule'),
                    value: filter.recurringOnly,
                    onChanged: (v) =>
                        update(filter.copyWith(recurringOnly: v)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tasks with deadline only'),
                    subtitle: const Text('Tasks that have a hard deadline set'),
                    value: filter.hasDeadlineOnly,
                    onChanged: (v) =>
                        update(filter.copyWith(hasDeadlineOnly: v)),
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
  final TaskFilter filter;
  final void Function(TaskFilter) onUpdate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat.MMMd();
    final isCustom = filter.dateFilter == TaskDateFilter.custom;

    Future<void> pickRange() async {
      final from = await pickDate(context,
          initial: filter.customRangeStart ?? DateTime.now());
      if (from == null || !context.mounted) return;
      final to = await pickDate(context,
          initial: filter.customRangeEnd ?? from,
          firstDate: from);
      if (to == null) return;
      onUpdate(filter.copyWith(
        dateFilter: TaskDateFilter.custom,
        customRangeStart: from,
        customRangeEnd: to,
      ));
    }

    return Row(
      children: [
        AppChip(
          label: isCustom && filter.customRangeStart != null
              ? '${fmt.format(filter.customRangeStart!)} – ${fmt.format(filter.customRangeEnd ?? filter.customRangeStart!)}'
              : 'Custom range…',
          icon: Icons.date_range_rounded,
          selected: isCustom,
          color: const Color(0xFF3B82F6),
          onTap: pickRange,
        ),
        if (isCustom) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onUpdate(filter.copyWith(
              dateFilter: TaskDateFilter.all,
              customRangeStart: null,
              customRangeEnd: null,
            )),
            child: Icon(Icons.close_rounded, size: 18, color: cs.onSurfaceVariant),
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
