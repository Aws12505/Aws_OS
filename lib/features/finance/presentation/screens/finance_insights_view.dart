import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/charts/category_donut.dart';
import '../../../../shared/widgets/charts/grouped_bar_chart.dart';
import '../../../../shared/widgets/charts/trend_line_chart.dart';
import '../../../../shared/widgets/insights_card.dart';
import '../../../../shared/widgets/segmented_control.dart';
import '../../../../shared/widgets/stat_tile.dart';
import '../../../../shared/utils/insights_range.dart';
import '../../../dashboard/data/insights_service.dart';
import '../../../dashboard/presentation/insights_providers.dart';
import '../../../dashboard/presentation/widgets/insights_range_selector.dart';
import '../../data/finance_breakdown.dart';
import '../../data/finance_dao.dart';
import '../providers.dart' as fin;

/// The Finance → Insights tab: every financial chart, per currency, in more
/// detail than the dashboard (income/expense/net, category & type donut,
/// income-vs-expense, balance trend, projection) plus budgets.
class FinanceInsightsView extends ConsumerWidget {
  const FinanceInsightsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(insightsRangeProvider);
    final (start, end) = range.window(DateTime.now());
    final rangeTxs =
        ref.watch(fin.transactionsInRangeProvider((start: start, end: end)))
            .value ??
        const <TransactionWithLegs>[];
    final catNames = {
      for (final c
          in (ref.watch(fin.allCategoriesProvider).value ?? const <Category>[]))
        c.id: c.name,
    };
    final typeNames = {
      for (final t
          in (ref.watch(fin.allTypesProvider).value ??
              const <CategoryType>[]))
        t.id: t.name,
    };
    final ciA = ref.watch(currencyInsightsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
      children: [
        const InsightsRangeSelector(),
        ciA.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 40),
            child: AppLoading(),
          ),
          error: (e, _) => AppErrorView(error: e),
          data: (list) {
            final shown = list
                .where((c) => c.hasActivity || c.currentBalance != 0)
                .toList();
            if (shown.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 40),
                child: AppEmptyState(
                  icon: Icons.insights_rounded,
                  title: 'No finance activity',
                  message: 'Add transactions to see per-currency insights.',
                ),
              );
            }
            return Column(
              children: [
                for (final c in shown)
                  _CurrencyInsightCard(
                    insight: c,
                    rangeTxs: rangeTxs,
                    catNames: catNames,
                    typeNames: typeNames,
                  ),
              ],
            );
          },
        ),
        const _BudgetsCard(),
      ],
    );
  }
}

class _CurrencyInsightCard extends StatefulWidget {
  const _CurrencyInsightCard({
    required this.insight,
    required this.rangeTxs,
    required this.catNames,
    required this.typeNames,
  });

  final CurrencyInsight insight;
  final List<TransactionWithLegs> rangeTxs;
  final Map<String, String> catNames;
  final Map<String, String> typeNames;

  @override
  State<_CurrencyInsightCard> createState() => _CurrencyInsightCardState();
}

class _CurrencyInsightCardState extends State<_CurrencyInsightCard> {
  String _kind = 'expense';
  bool _byType = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ins = widget.insight;
    final cur = ins.currency;

    final slices = categoryBreakdown(
      txs: widget.rangeTxs,
      kind: _kind,
      currencyId: cur.id,
      byType: _byType,
      catNames: widget.catNames,
      typeNames: widget.typeNames,
    );
    final data = <DonutDatum>[];
    final capped = slices.length > 6 ? slices.sublist(0, 6) : slices;
    for (var i = 0; i < capped.length; i++) {
      data.add(
        DonutDatum(
          label: capped[i].label,
          value: capped[i].amount,
          color: ChartPalette.at(i),
        ),
      );
    }
    if (slices.length > 6) {
      final other = slices.sublist(6).fold<double>(0, (s, x) => s + x.amount);
      data.add(DonutDatum(label: 'Other', value: other, color: ChartPalette.at(6)));
    }
    final donutTotal = slices.fold<double>(0, (s, x) => s + x.amount);
    final nf = NumberFormat.compact();

    return InsightsCard(
      icon: Icons.account_balance_wallet_rounded,
      color: context.sem.income.base,
      title: cur.code,
      subtitle: 'Balance ${_full(ins.currentBalance, cur)}',
      takeaway: _flowTakeaway(ins, cur),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Income',
                  value: _money(ins.totalIncome, cur),
                  accent: context.sem.income.base,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricCard(
                  label: 'Expense',
                  value: _money(ins.totalExpense, cur),
                  accent: context.sem.expense.base,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricCard(
                  label: 'Net',
                  value: _money(ins.netFlow, cur),
                  valueColor: ins.netFlow >= 0
                      ? context.sem.income.base
                      : context.sem.expense.base,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedControl(
            margin: EdgeInsets.zero,
            labels: const ['Expense', 'Income'],
            index: _kind == 'income' ? 1 : 0,
            onTap: (i) => setState(() => _kind = i == 1 ? 'income' : 'expense'),
          ),
          const SizedBox(height: 8),
          SegmentedControl(
            margin: EdgeInsets.zero,
            labels: const ['By category', 'By type'],
            index: _byType ? 1 : 0,
            onTap: (i) => setState(() => _byType = i == 1),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (data.isEmpty)
            SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  'No ${_kind == 'income' ? 'income' : 'expenses'} in range',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            CategoryDonut(
              data: data,
              centerValue: nf.format(donutTotal),
              centerLabel: cur.code,
              legendValue: nf.format,
            ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Income vs expense',
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          GroupedBarChart(
            xLabels: ins.labels,
            leftFormatter: compactNumber,
            series: [
              BarSeries(
                label: 'Income',
                color: context.sem.income.base,
                values: ins.incomes,
              ),
              BarSeries(
                label: 'Expense',
                color: context.sem.expense.base,
                values: ins.expenses,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Balance trend',
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TrendLineChart(
            height: 120,
            xLabels: ins.labels,
            leftFormatter: compactNumber,
            series: [
              LineSeries(
                values: [for (final v in ins.balanceSeries) v],
                color: cs.primary,
                fill: true,
              ),
            ],
          ),
        ],
      ),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fmt = NumberFormat.decimalPattern();
    return InsightsCard(
      icon: Icons.savings_rounded,
      color: context.sem.warning.base,
      title: 'Budgets',
      subtitle: DateFormat('MMMM').format(DateTime.now()),
      takeaway: _budgetTakeaway(list),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final b in list)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.weight(FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${fmt.format(b.spent)} / ${fmt.format(b.budget.amount)}',
                        style: tt.labelMedium?.copyWith(
                          color: b.over ? context.sem.expense.base : cs.onSurface,
                        ).weight(FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: LinearProgressIndicator(
                      value: b.fraction,
                      minHeight: 7,
                      backgroundColor: context.surfaces.sunken,
                      color: b.over
                          ? context.sem.expense.base
                          : b.rawFraction > 0.85
                          ? context.sem.warning.base
                          : context.sem.income.base,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _money(double v, Currency c) =>
    '${compactNumber(v)} ${c.symbol.isNotEmpty ? c.symbol : c.code}';

String _full(double v, Currency c) =>
    '${NumberFormat.decimalPatternDigits(decimalDigits: c.decimalPlaces).format(v)} '
    '${c.symbol.isNotEmpty ? c.symbol : c.code}';

/// Whether this currency gained or lost over the selected range.
String? _flowTakeaway(CurrencyInsight ins, Currency cur) {
  if (!ins.hasActivity) return null;
  final net = ins.netFlow;
  if (net > 0) return 'Up ${_full(net, cur)} over this range.';
  if (net < 0) return 'Down ${_full(net.abs(), cur)} over this range.';
  return 'Income and spending balanced out over this range.';
}

/// Which budget needs attention, so the bars do not have to be scanned.
String? _budgetTakeaway(List<BudgetActual> list) {
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
  return percent >= 80
      ? '${tightest.category.name} is the tightest at $percent% used.'
      : 'Every budget still has room, the tightest at $percent%.';
}
