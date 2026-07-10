import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/tokens.dart';
import '../../../../shared/utils/date_preset.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../../../shared/widgets/date_time_picker.dart';
import '../providers.dart';
import '../transaction_filter.dart';

void showTransactionFilterSheet(BuildContext context) {
  showAppModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const _TransactionFilterSheet(),
  );
}

const _kinds = ['all', 'income', 'expense', 'transfer', 'exchange'];

class _TransactionFilterSheet extends ConsumerWidget {
  const _TransactionFilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filter = ref.watch(transactionFilterProvider);
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];

    void update(TransactionFilter f) =>
        ref.read(transactionFilterProvider.notifier).state = f;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
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
                    'Filter transactions',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: filter.isDefault
                        ? null
                        : () => update(const TransactionFilter()),
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
                  // ── TYPE ─────────────────────────────────────────────
                  const _SectionLabel('TYPE'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final k in _kinds)
                        AppChip(
                          label: k == 'all'
                              ? 'All'
                              : DomainColors.labelForTxKind(k),
                          color: k == 'all'
                              ? cs.primary
                              : DomainColors.forTxKind(k),
                          selected: filter.kind == k,
                          onTap: () => update(filter.copyWith(kind: k)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── DATE ─────────────────────────────────────────────
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
                            color: DomainColors.tasks,
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

                  // ── CATEGORY ─────────────────────────────────────────
                  if (categories.isNotEmpty) ...[
                    const _SectionLabel('CATEGORY'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppChip(
                          label: 'All',
                          color: cs.primary,
                          selected: filter.categoryId == null,
                          onTap: () => update(
                            filter.copyWith(categoryId: null, typeId: null),
                          ),
                        ),
                        for (final c in categories)
                          AppChip(
                            label: c.name,
                            color: DomainColors.forTxKind(c.kind),
                            selected: filter.categoryId == c.id,
                            onTap: () => update(
                              filter.copyWith(
                                categoryId: filter.categoryId == c.id
                                    ? null
                                    : c.id,
                                typeId: null,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── SUBCATEGORY (depends on chosen category) ─────────
                  if (filter.categoryId != null)
                    _SubcategorySection(
                      categoryId: filter.categoryId!,
                      filter: filter,
                      onUpdate: update,
                    ),

                  // ── RECURRENCE ───────────────────────────────────────
                  const _SectionLabel('RECURRENCE'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in TxRecurring.values)
                        AppChip(
                          label: r.label,
                          icon: r == TxRecurring.recurring
                              ? Icons.autorenew_rounded
                              : r == TxRecurring.oneOff
                              ? Icons.bolt_rounded
                              : null,
                          color: DomainColors.warning,
                          selected: filter.recurring == r,
                          onTap: () => update(filter.copyWith(recurring: r)),
                        ),
                    ],
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

class _SubcategorySection extends ConsumerWidget {
  const _SubcategorySection({
    required this.categoryId,
    required this.filter,
    required this.onUpdate,
  });

  final String categoryId;
  final TransactionFilter filter;
  final void Function(TransactionFilter) onUpdate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final types =
        ref.watch(typesForCategoryProvider(categoryId)).value ??
        const <CategoryType>[];
    if (types.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('SUBCATEGORY'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppChip(
              label: 'All',
              color: cs.primary,
              selected: filter.typeId == null,
              onTap: () => onUpdate(filter.copyWith(typeId: null)),
            ),
            for (final t in types)
              AppChip(
                label: t.name,
                color: DomainColors.exchange,
                selected: filter.typeId == t.id,
                onTap: () => onUpdate(
                  filter.copyWith(typeId: filter.typeId == t.id ? null : t.id),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _CustomDateRow extends StatelessWidget {
  const _CustomDateRow({required this.filter, required this.onUpdate});
  final TransactionFilter filter;
  final void Function(TransactionFilter) onUpdate;

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
          color: DomainColors.tasks,
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
