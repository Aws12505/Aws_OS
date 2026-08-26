part of '../../insights_view.dart';

// The headline numbers for the selected range.

class _KpiStrip extends ConsumerWidget {
  const _KpiStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(insightsRangeSummaryProvider).value;
    final prod = ref.watch(productivityForecastProvider).value;
    final ci = ref.watch(currencyInsightsProvider).value;

    if (rs == null) {
      return const SizedBox(height: 96, child: AppLoading());
    }

    final cards = <Widget>[];

    // One net tile per active currency — never summed across currencies.
    if (ci != null) {
      for (final c in ci) {
        cards.add(
          _kpi(
            label: 'Net · ${c.currency.code}',
            value: _money(c.netFlow, c.currency),
            icon: Icons.trending_up_rounded,
            color: c.netFlow >= 0 ? context.sem.income.base : context.sem.expense.base,
          ),
        );
      }
    }

    final completion = (rs.avgTaskCompletion * 100).round();
    cards.add(
      _kpi(
        label: 'Tasks done',
        value: rs.totalTasksDue == 0 ? '-' : '$completion%',
        icon: Icons.task_alt_rounded,
        color: context.sem.tasks.base,
      ),
    );
    cards.add(
      _kpi(
        label: 'Workouts',
        value: '${rs.totalWorkouts}',
        icon: Icons.fitness_center_rounded,
        color: context.sem.gym.base,
      ),
    );
    if (prod != null) {
      cards.add(
        _kpi(
          label: 'Overdue',
          value: '${prod.overdue}',
          icon: Icons.warning_amber_rounded,
          color: prod.overdue > 0 ? context.sem.warning.base : context.sem.neutral.base,
        ),
      );
    }
    cards.add(
      _kpi(
        label: 'Avg mood',
        value: rs.avgMood == 0 ? '-' : rs.avgMood.toStringAsFixed(1),
        icon: Icons.sentiment_satisfied_rounded,
        color: context.sem.chartAt(6),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: MetricGrid(tiles: cards),
    );
  }

  Widget _kpi({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) => MetricCard(label: label, value: value, icon: icon, accent: color);
}
