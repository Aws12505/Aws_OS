part of '../../insights_view.dart';

// Budgets against what was actually spent.

class _BudgetsCard extends ConsumerWidget {
  const _BudgetsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(budgetVsActualProvider).value ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    return InsightsCard(
      icon: Icons.savings_rounded,
      color: context.sem.warning.base,
      title: 'Budgets',
      subtitle: DateFormat('MMMM').format(now),
      takeaway: _budgetsTakeaway(list),
      onTap: () => context.go('/finance'),
      child: Column(children: [for (final b in list) _BudgetRow(item: b)]),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.item});
  final BudgetActual item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fmt = NumberFormat.decimalPattern();
    final barColor = item.over
        ? context.sem.expense.base
        : item.rawFraction > 0.85
        ? context.sem.warning.base
        : context.sem.income.base;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.category.name,
                  style: tt.bodyMedium?.weight(FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${fmt.format(item.spent)} / ${fmt.format(item.budget.amount)}',
                style: tt.labelMedium?.copyWith(
                  color: item.over ? context.sem.expense.base : cs.onSurface,
                ).weight(FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: item.fraction,
              minHeight: 7,
              backgroundColor: cs.surfaceContainerHighest,
              color: barColor,
            ),
          ),
        ],
      ),
    );
  }
}


/// Which budget needs attention, rather than making the reader scan the bars.
String? _budgetsTakeaway(List<BudgetActual> list) {
  if (list.isEmpty) return null;
  final over = list.where((b) => b.over).toList();
  if (over.isNotEmpty) {
    final worst = over.reduce((a, b) => b.rawFraction > a.rawFraction ? b : a);
    return over.length == 1
        ? '${worst.category.name} is over budget.'
        : '${over.length} budgets are over, ${worst.category.name} by the most.';
  }
  final tightest = list.reduce((a, b) => b.rawFraction > a.rawFraction ? b : a);
  final percent = (tightest.rawFraction * 100).round();
  if (percent >= 80) {
    return '${tightest.category.name} is the tightest at $percent% used.';
  }
  return 'Every budget still has room, the tightest at $percent%.';
}
