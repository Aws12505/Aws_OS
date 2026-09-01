part of '../dashboard_screen.dart';

// Where the money went, by category.

/// This-month income/expense broken down by category or subcategory (type),
/// as a clean donut. Per currency — never mixes currencies.
class _SpendingBreakdownCard extends ConsumerStatefulWidget {
  const _SpendingBreakdownCard();
  @override
  ConsumerState<_SpendingBreakdownCard> createState() =>
      _SpendingBreakdownCardState();
}

class _SpendingBreakdownCardState
    extends ConsumerState<_SpendingBreakdownCard> {
  String _kind = 'expense';
  bool _byType = false;

  @override
  Widget build(BuildContext context) {
    final txs =
        ref.watch(fin.recentTransactionsStreamProvider).value ??
        const <TransactionWithLegs>[];
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final hasAny = txs.any(
      (t) =>
          (t.transaction.kind == 'income' ||
              t.transaction.kind == 'expense') &&
          !t.transaction.occurredAt.isBefore(monthStart),
    );
    if (!hasAny) return const SizedBox.shrink();

    final cats =
        ref.watch(fin.allCategoriesProvider).value ?? const <Category>[];
    final types =
        ref.watch(fin.allTypesProvider).value ?? const <CategoryType>[];
    final currencies = {
      for (final c
          in (ref.watch(fin.currenciesStreamProvider).value ??
              const <Currency>[]))
        c.id: c,
    };
    final catNames = {for (final c in cats) c.id: c.name};
    final typeNames = {for (final t in types) t.id: t.name};

    final curId = dominantCurrencyFor(txs: txs, kind: _kind, from: monthStart);
    final cur = curId != null ? currencies[curId] : null;
    final slices = curId == null
        ? const <BreakdownSlice>[]
        : categoryBreakdown(
            txs: txs,
            kind: _kind,
            currencyId: curId,
            byType: _byType,
            catNames: catNames,
            typeNames: typeNames,
            from: monthStart,
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
    final total = slices.fold<double>(0, (s, x) => s + x.amount);
    final nf = NumberFormat.compact();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final income = _kind == 'income';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(
                icon: income
                    ? Icons.trending_up_rounded
                    : Icons.donut_large_rounded,
                color: income ? DomainColors.income : cs.error,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      income ? 'Income' : 'Spending',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${DateFormat('MMMM y').format(now)}'
                      '${cur != null ? ' · ${cur.code}' : ''}',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SegmentedControl(
            margin: EdgeInsets.zero,
            labels: const ['Expense', 'Income'],
            index: income ? 1 : 0,
            onTap: (i) => setState(() => _kind = i == 1 ? 'income' : 'expense'),
          ),
          const SizedBox(height: 8),
          SegmentedControl(
            margin: EdgeInsets.zero,
            labels: const ['By category', 'By type'],
            index: _byType ? 1 : 0,
            onTap: (i) => setState(() => _byType = i == 1),
          ),
          const SizedBox(height: 18),
          if (slices.isEmpty)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'No ${income ? 'income' : 'expenses'} in '
                  '${DateFormat('MMMM').format(now)}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            CategoryDonut(
              data: data,
              centerValue: nf.format(total),
              centerLabel: cur?.code,
              legendValue: nf.format,
            ),
        ],
      ),
    );
  }
}
