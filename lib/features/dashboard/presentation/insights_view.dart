import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../shared/design/tokens.dart';
import '../../../shared/widgets/charts/activity_heatmap.dart';
import '../../../shared/widgets/charts/grouped_bar_chart.dart';
import '../../../shared/widgets/charts/trend_line_chart.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/sparkline.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../mentor/data/forecast_service.dart';
import '../../mentor/presentation/mentor_providers.dart';
import '../data/day_summary.dart';
import '../../../shared/utils/insights_range.dart';
import '../data/insights_service.dart';
import 'insights_providers.dart';

/// The "Insights" tab of the dashboard: a range selector followed by analytics
/// sections. Each section watches its own providers and self-hides when empty,
/// mirroring the Overview cards.
class InsightsView extends StatelessWidget {
  const InsightsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 120),
      children: const [
        _RangeSelector(),
        _KpiStrip(),
        _FinanceSection(),
        _BudgetsCard(),
        _ProductivitySection(),
        _GymSection(),
        _WellbeingSection(),
        _ConsistencyCard(),
      ],
    );
  }
}

// ── range selector ───────────────────────────────────────────────────────────

class _RangeSelector extends ConsumerWidget {
  const _RangeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(insightsRangeProvider);
    const ranges = InsightsRange.values;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SegmentedRow(
        labels: [for (final r in ranges) r.label],
        index: ranges.indexOf(range),
        onTap: (i) =>
            ref.read(insightsRangeProvider.notifier).state = ranges[i],
      ),
    );
  }
}

/// Thin wrapper around the shared segmented control so this file doesn't import
/// it under a name that clashes with the dashboard toggle.
class SegmentedRow extends StatelessWidget {
  const SegmentedRow({
    super.key,
    required this.labels,
    required this.index,
    required this.onTap,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 6,
      ),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.72),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? cs.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    labels[i],
                    style: tt.labelLarge?.copyWith(
                      color: i == index ? cs.onPrimary : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── KPI strip ────────────────────────────────────────────────────────────────

class _KpiStrip extends ConsumerWidget {
  const _KpiStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(insightsRangeSummaryProvider).value;
    final prod = ref.watch(productivityForecastProvider).value;
    final ci = ref.watch(currencyInsightsProvider).value;

    if (rs == null) {
      return const SizedBox(height: 96, child: Center(child: _Dots()));
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
            color: c.netFlow >= 0 ? DomainColors.income : DomainColors.expense,
          ),
        );
      }
    }

    final completion = (rs.avgTaskCompletion * 100).round();
    cards.add(
      _kpi(
        label: 'Tasks done',
        value: rs.totalTasksDue == 0 ? '—' : '$completion%',
        icon: Icons.task_alt_rounded,
        color: DomainColors.tasks,
      ),
    );
    cards.add(
      _kpi(
        label: 'Workouts',
        value: '${rs.totalWorkouts}',
        icon: Icons.fitness_center_rounded,
        color: DomainColors.gym,
      ),
    );
    if (prod != null) {
      cards.add(
        _kpi(
          label: 'Overdue',
          value: '${prod.overdue}',
          icon: Icons.warning_amber_rounded,
          color: prod.overdue > 0 ? DomainColors.warning : DomainColors.neutral,
        ),
      );
    }
    cards.add(
      _kpi(
        label: 'Avg mood',
        value: rs.avgMood == 0 ? '—' : rs.avgMood.toStringAsFixed(1),
        icon: Icons.sentiment_satisfied_rounded,
        color: const Color(0xFFEC4899),
      ),
    );

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => SizedBox(width: 138, child: cards[i]),
      ),
    );
  }

  Widget _kpi({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) => MetricCard(label: label, value: value, icon: icon, accent: color);
}

// ── finance (per currency) ───────────────────────────────────────────────────

class _FinanceSection extends ConsumerWidget {
  const _FinanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ciA = ref.watch(currencyInsightsProvider);
    final forecasts = ref.watch(financeForecastsAllProvider).value ?? const [];
    final byCode = {for (final f in forecasts) f.currencyCode: f};

    return ciA.maybeWhen(
      orElse: () => const _LoadingCard(),
      data: (list) {
        final shown = list.where((c) => c.hasActivity || c.currentBalance != 0);
        if (shown.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (final c in shown)
              _CurrencyCard(insight: c, forecast: byCode[c.currency.code]),
          ],
        );
      },
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  const _CurrencyCard({required this.insight, this.forecast});
  final CurrencyInsight insight;
  final FinanceForecast? forecast;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cur = insight.currency;

    return _SectionCard(
      icon: Icons.account_balance_wallet_rounded,
      color: DomainColors.income,
      title: 'Finance · ${cur.code}',
      subtitle: 'Balance ${_full(insight.currentBalance, cur)}',
      onTap: () => context.go('/finance'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legend(const [
            (DomainColors.income, 'Income'),
            (DomainColors.expense, 'Expense'),
          ]),
          const SizedBox(height: AppSpacing.sm),
          GroupedBarChart(
            xLabels: insight.labels,
            leftFormatter: compactNumber,
            series: [
              BarSeries(
                label: 'Income',
                color: DomainColors.income,
                values: insight.incomes,
              ),
              BarSeries(
                label: 'Expense',
                color: DomainColors.expense,
                values: insight.expenses,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Balance trend',
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TrendLineChart(
            height: 120,
            xLabels: insight.labels,
            leftFormatter: compactNumber,
            series: [
              LineSeries(
                values: [for (final v in insight.balanceSeries) v],
                color: cs.primary,
                fill: true,
              ),
            ],
          ),
          if (forecast != null && forecast!.hasData) ...[
            const SizedBox(height: AppSpacing.lg),
            _projection(context, forecast!, cur),
          ],
        ],
      ),
    );
  }

  Widget _projection(BuildContext context, FinanceForecast f, Currency cur) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final proj = f.projected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Projected balance',
          style: tt.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final n in const [1, 3, 6])
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: n == 6 ? 0 : 8),
                  child: MetricCard(
                    label: '+${n}mo',
                    value: _money(proj[n] ?? f.currentBalance, cur),
                    valueColor: (proj[n] ?? 0) >= f.currentBalance
                        ? DomainColors.income
                        : DomainColors.expense,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Icon(
              f.growing
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              size: 15,
              color: f.growing ? DomainColors.income : DomainColors.warning,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                f.runwayMonths != null
                    ? 'Burning down — about ${f.runwayMonths!.toStringAsFixed(1)} months of runway'
                    : 'Avg ${_money(f.avgMonthlyNet, cur)} / month',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── budgets ──────────────────────────────────────────────────────────────────

class _BudgetsCard extends ConsumerWidget {
  const _BudgetsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(budgetVsActualProvider).value ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    return _SectionCard(
      icon: Icons.savings_rounded,
      color: DomainColors.warning,
      title: 'Budgets',
      subtitle: DateFormat('MMMM').format(now),
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
        ? DomainColors.expense
        : item.rawFraction > 0.85
        ? DomainColors.warning
        : DomainColors.income;
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
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${fmt.format(item.spent)} / ${fmt.format(item.budget.amount)}',
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: item.over ? DomainColors.expense : cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
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

// ── productivity ─────────────────────────────────────────────────────────────

class _ProductivitySection extends ConsumerWidget {
  const _ProductivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(insightsRangeSummaryProvider).value;
    final prod = ref.watch(productivityForecastProvider).value;
    if (rs == null) return const _LoadingCard();
    if (rs.totalTasksDue == 0 && (prod?.overdue ?? 0) == 0) {
      return const SizedBox.shrink();
    }
    final labels = _labels(rs);
    final series = [
      for (final d in rs.days) d.tasksDue > 0 ? d.taskCompletion * 100 : null,
    ];

    return _SectionCard(
      icon: Icons.task_alt_rounded,
      color: DomainColors.tasks,
      title: 'Productivity',
      subtitle: '${rs.totalTasksDone}/${rs.totalTasksDue} tasks completed',
      onTap: () => context.go('/tasks'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Completion',
                  value: rs.totalTasksDue == 0
                      ? '—'
                      : '${(rs.avgTaskCompletion * 100).round()}%',
                  accent: DomainColors.tasks,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricCard(
                  label: 'Done',
                  value: '${rs.totalTasksDone}',
                  accent: DomainColors.tasks,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricCard(
                  label: 'Overdue',
                  value: '${prod?.overdue ?? 0}',
                  accent: DomainColors.warning,
                  valueColor: (prod?.overdue ?? 0) > 0
                      ? DomainColors.warning
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Daily completion rate',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TrendLineChart(
            height: 140,
            xLabels: labels,
            leftFormatter: (v) => '${v.round()}%',
            series: [
              LineSeries(values: series, color: DomainColors.tasks, fill: true),
            ],
          ),
        ],
      ),
    );
  }
}

// ── gym & body ───────────────────────────────────────────────────────────────

class _GymSection extends ConsumerWidget {
  const _GymSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(insightsRangeSummaryProvider).value;
    final gym = ref.watch(gymForecastProvider).value;
    if (rs == null) return const _LoadingCard();
    final measurements = gym?.measurements ?? const <MeasurementTrend>[];
    if (rs.totalWorkouts == 0 && measurements.isEmpty) {
      return const SizedBox.shrink();
    }

    // Weekly workout counts across the range.
    final weekly = <DateTime, int>{};
    for (final d in rs.days) {
      final wk = _mondayOf(d.date);
      weekly.update(
        wk,
        (v) => v + d.sessionCount,
        ifAbsent: () => d.sessionCount,
      );
    }
    final weeks = weekly.keys.toList()..sort();
    final weekLabels = [for (final w in weeks) DateFormat('d/M').format(w)];
    final weekValues = [for (final w in weeks) weekly[w]!.toDouble()];

    return _SectionCard(
      icon: Icons.fitness_center_rounded,
      color: DomainColors.gym,
      title: 'Gym & body',
      subtitle: gym == null
          ? null
          : '${gym.sessionsPerWeek.toStringAsFixed(1)}/wk · streak ${gym.currentWeekStreak}w',
      onTap: () => context.go('/gym'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (weekValues.any((v) => v > 0)) ...[
            Text(
              'Workouts per week',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            GroupedBarChart(
              height: 130,
              xLabels: weekLabels,
              series: [
                BarSeries(
                  label: 'Workouts',
                  color: DomainColors.gym,
                  values: weekValues,
                ),
              ],
            ),
          ],
          if (measurements.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Body measurements',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final m in measurements.take(4)) _MeasurementRow(trend: m),
          ],
        ],
      ),
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  const _MeasurementRow({required this.trend});
  final MeasurementTrend trend;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final up = trend.change > 0;
    final flat = trend.change.abs() < 1e-9;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              trend.name,
              style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Sparkline(
              values: trend.series,
              color: cs.primary,
              height: 28,
              fill: true,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_trim(trend.latest)}${trend.unit}',
                style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Row(
                children: [
                  Icon(
                    flat
                        ? Icons.remove_rounded
                        : up
                        ? Icons.north_east_rounded
                        : Icons.south_east_rounded,
                    size: 11,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${_trim(trend.change.abs())}${trend.unit}',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

// ── wellbeing ────────────────────────────────────────────────────────────────

class _WellbeingSection extends ConsumerWidget {
  const _WellbeingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(insightsRangeSummaryProvider).value;
    if (rs == null) return const SizedBox.shrink();
    if (rs.daysWithDebrief == 0) return const SizedBox.shrink();

    const moodColor = Color(0xFF8B5CF6);
    const energyColor = Color(0xFF14B8A6);
    final labels = _labels(rs);
    final mood = [for (final d in rs.days) d.debrief?.mood?.toDouble()];
    final energy = [for (final d in rs.days) d.debrief?.energy?.toDouble()];

    return _SectionCard(
      icon: Icons.self_improvement_rounded,
      color: const Color(0xFFEC4899),
      title: 'Wellbeing',
      subtitle: '${rs.daysWithDebrief} days journaled',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Avg mood',
                  value: rs.avgMood == 0 ? '—' : rs.avgMood.toStringAsFixed(1),
                  accent: moodColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricCard(
                  label: 'Avg energy',
                  value: rs.avgEnergy == 0
                      ? '—'
                      : rs.avgEnergy.toStringAsFixed(1),
                  accent: energyColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _legend(const [(moodColor, 'Mood'), (energyColor, 'Energy')]),
          const SizedBox(height: AppSpacing.sm),
          TrendLineChart(
            height: 130,
            xLabels: labels,
            leftFormatter: (v) => v.round().toString(),
            series: [
              LineSeries(values: mood, color: moodColor),
              LineSeries(values: energy, color: energyColor),
            ],
          ),
        ],
      ),
    );
  }
}

// ── consistency heatmap ──────────────────────────────────────────────────────

class _ConsistencyCard extends ConsumerWidget {
  const _ConsistencyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(insightsRangeSummaryProvider).value;
    if (rs == null || rs.days.length < 2) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final cells = [
      for (final d in rs.days) HeatCell(date: d.date, intensity: _intensity(d)),
    ];
    if (cells.every((c) => c.intensity <= 0)) return const SizedBox.shrink();

    return _SectionCard(
      icon: Icons.grid_view_rounded,
      color: cs.primary,
      title: 'Consistency',
      subtitle: 'Daily activity across all areas',
      child: ActivityHeatmap(cells: cells, color: cs.primary),
    );
  }

  double _intensity(DaySummary d) {
    if (!d.hasActivity) return 0;
    var v = 0.25;
    if (d.tasksDue > 0) v = 0.25 + 0.55 * d.taskCompletion;
    if (d.workedOut) v += 0.2;
    if (d.notesCount > 0) v += 0.1;
    return v.clamp(0.0, 1.0);
  }
}

// ── shared bits ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const GlassCard(
    child: SizedBox(height: 120, child: Center(child: _Dots())),
  );
}

class _Dots extends StatelessWidget {
  const _Dots();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 24,
    height: 24,
    child: CircularProgressIndicator(strokeWidth: 3),
  );
}

Widget _legend(List<(Color, String)> items) {
  return Builder(
    builder: (context) {
      final tt = Theme.of(context).textTheme;
      final cs = Theme.of(context).colorScheme;
      return Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          for (final (color, label) in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
        ],
      );
    },
  );
}

List<String> _labels(RangeSummary rs) {
  final fmt = rs.days.length <= 8 ? DateFormat('E') : DateFormat('d/M');
  return [for (final d in rs.days) fmt.format(d.date)];
}

DateTime _mondayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

String _money(double v, Currency c) =>
    '${compactNumber(v)} ${c.symbol.isNotEmpty ? c.symbol : c.code}';

String _full(double v, Currency c) =>
    '${NumberFormat.decimalPatternDigits(decimalDigits: c.decimalPlaces).format(v)} ${c.symbol.isNotEmpty ? c.symbol : c.code}';
