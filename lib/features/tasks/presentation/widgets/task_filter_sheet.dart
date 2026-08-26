import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../../../shared/widgets/date_range_row.dart';
import '../../../../shared/widgets/section_header.dart';
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
                  borderRadius: BorderRadius.circular(AppRadius.xs),
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
                          ),
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
                  SectionLabel('Status'),
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
                  SectionLabel('Due date'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TaskDateFilter.values
                        .where((d) => d != TaskDateFilter.custom)
                        .map((d) => AppChip(
                              label: d.label,
                              selected: filter.dateFilter == d,
                              color: context.sem.transfer.base,
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
                  DateRangeRow(
                    from: filter.customRangeStart,
                    to: filter.customRangeEnd,
                    selected: filter.dateFilter == TaskDateFilter.custom,
                    color: context.sem.tasks.base,
                    onPicked: (from, to) => update(
                      filter.copyWith(
                        dateFilter: TaskDateFilter.custom,
                        customRangeStart: from,
                        customRangeEnd: to,
                      ),
                    ),
                    onCleared: () => update(
                      filter.copyWith(
                        dateFilter: TaskDateFilter.all,
                        customRangeStart: null,
                        customRangeEnd: null,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── CATEGORY ─────────────────────────────────────────
                  if (categories.isNotEmpty) ...[
                    SectionLabel('Category'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppChip(
                          label: 'All',
                          selected: filter.category == null,
                          color: context.sem.exchange.base,
                          onTap: () =>
                              update(filter.copyWith(category: null)),
                        ),
                        ...categories.map((c) => AppChip(
                              label: c,
                              selected: filter.category == c,
                              color: context.sem.exchange.base,
                              onTap: () => update(filter.copyWith(category: c)),
                            )),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── OPTIONS ──────────────────────────────────────────
                  SectionLabel('Options'),
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

