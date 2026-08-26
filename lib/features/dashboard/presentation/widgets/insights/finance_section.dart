part of '../../insights_view.dart';

// Money in, money out, per currency.

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

    return InsightsCard(
      icon: Icons.account_balance_wallet_rounded,
      color: context.sem.income.base,
      title: 'Finance · ${cur.code}',
      subtitle: 'Balance ${_full(insight.currentBalance, cur)}',
      takeaway: _financeTakeaway(insight, forecast, cur),
      onTap: () => context.go('/finance'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legend([
            (context.sem.income.base, 'Income'),
            (context.sem.expense.base, 'Expense'),
          ]),
          const SizedBox(height: AppSpacing.sm),
          GroupedBarChart(
            xLabels: insight.labels,
            leftFormatter: compactNumber,
            series: [
              BarSeries(
                label: 'Income',
                color: context.sem.income.base,
                values: insight.incomes,
              ),
              BarSeries(
                label: 'Expense',
                color: context.sem.expense.base,
                values: insight.expenses,
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
                        ? context.sem.income.base
                        : context.sem.expense.base,
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
              color: f.growing ? context.sem.income.base : context.sem.warning.base,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                f.runwayMonths != null
                    ? 'Burning down, about ${f.runwayMonths!.toStringAsFixed(1)} months of runway'
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

/// Whether the range added up or ran down, and what that implies. Runway is
/// only mentioned when the forecast service actually computed one, which it
/// does only while burning down.
String? _financeTakeaway(
  CurrencyInsight insight,
  FinanceForecast? forecast,
  Currency cur,
) {
  if (!insight.hasActivity) return null;
  final net = insight.netFlow;
  final runway = forecast?.runwayMonths;

  if (net < 0 && runway != null) {
    return 'Down ${_full(net.abs(), cur)} over this range, about '
        '${runway.toStringAsFixed(1)} months of runway at that rate.';
  }
  if (net < 0) {
    return 'Down ${_full(net.abs(), cur)} over this range.';
  }
  if (net == 0) return 'Income and spending balanced out over this range.';
  return 'Up ${_full(net, cur)} over this range.';
}
