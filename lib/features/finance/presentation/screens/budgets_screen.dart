import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/utils/date_ext.dart';
import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../data/finance_dao.dart';
import '../providers.dart';

/// Monthly spending limits per expense category, with live progress.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(categoriesByKindProvider('expense'));
    final budgets =
        ref.watch(budgetsStreamProvider).value ?? const <Budget>[];
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final txs = ref
            .watch(transactionsInRangeProvider(
                (start: monthStart, end: now.atEndOfDay)))
            .value ??
        const <TransactionWithLegs>[];

    final spend = <String, double>{};
    for (final t in txs) {
      if (t.transaction.kind != 'expense') continue;
      final cid = t.transaction.categoryId;
      if (cid == null) continue;
      final amt = t.legs.fold<double>(0, (s, l) => s + l.amount.abs());
      spend.update(cid, (v) => v + amt, ifAbsent: () => amt);
    }
    final budgetByCat = {for (final b in budgets) b.categoryId: b};

    return AppScaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: catsAsync.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppErrorView(error: e),
        data: (categories) {
          if (categories.isEmpty) {
            return const AppEmptyState(
              icon: Icons.pie_chart_outline_rounded,
              title: 'No expense categories',
              message:
                  'Add expense categories first, then set monthly limits here.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                child: Text(
                  'Monthly limits for ${DateFormat('MMMM').format(now)}. Tap a category to set or change its budget.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
              for (final c in categories)
                _BudgetTile(
                  category: c,
                  budget: budgetByCat[c.id],
                  spent: spend[c.id] ?? 0,
                  onEdit: () =>
                      _editBudget(context, ref, c, budgetByCat[c.id]),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editBudget(
      BuildContext context, WidgetRef ref, Category c, Budget? existing) async {
    final ctrl = TextEditingController(
        text: existing == null ? '' : existing.amount.toStringAsFixed(0));
    final action = await showAppDialog<String>(
    context,
    builder: (dCtx) => AlertDialog(
        title: Text('Budget · ${c.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Monthly limit',
            hintText: 'e.g. 500',
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () => Navigator.pop(dCtx, 'clear'),
              child: const Text('Clear'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final dao = ref.read(financeDaoProvider);
    if (action == 'clear' && existing != null) {
      await dao.deleteBudget(existing.id);
    } else if (action == 'save') {
      final amt = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
      if (amt == null || amt <= 0) return;
      await dao.upsertBudget(BudgetsCompanion(
        id: existing == null ? const Value.absent() : Value(existing.id),
        categoryId: Value(c.id),
        amount: Value(amt),
        period: const Value('monthly'),
      ));
    }
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    required this.category,
    required this.budget,
    required this.spent,
    required this.onEdit,
  });

  final Category category;
  final Budget? budget;
  final double spent;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fmt = NumberFormat.decimalPattern();
    final limit = budget?.amount;
    final frac =
        (limit == null || limit <= 0) ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    final over = limit != null && spent > limit;
    final barColor = over
        ? context.sem.expense.base
        : frac > 0.85
            ? context.sem.warning.base
            : context.sem.income.base;

    return AppCard(
      style: CardStyle.block,
      margin: const EdgeInsets.symmetric(vertical: 5),
      radius: AppRadius.lg,
      onTap: onEdit,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        14,
        AppSpacing.lg,
        14,
      ),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(category.name,
                        style: tt.titleSmall
                            ?.weight(FontWeight.w700)),
                  ),
                  if (limit == null)
                    Text('Set budget',
                        style: tt.labelMedium?.copyWith(color: cs.primary))
                  else
                    Text('${fmt.format(spent)} / ${fmt.format(limit)}',
                        style: tt.labelLarge?.copyWith(
                          color: over ? context.sem.expense.base : cs.onSurface,
                        ).weight(FontWeight.w700)),
                ],
              ),
              if (limit != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 7,
                    backgroundColor: context.surfaces.sunken,
                    color: barColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  over
                      ? 'Over by ${fmt.format(spent - limit)}'
                      : '${fmt.format(limit - spent)} left',
                  style: tt.labelSmall?.copyWith(
                    color: over ? context.sem.expense.base : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
    );
  }
}
