import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_ext.dart';
import '../../finance/data/finance_dao.dart';
import '../../finance/presentation/providers.dart' as fin;
import '../../mentor/data/forecast_service.dart';
import '../../mentor/presentation/mentor_providers.dart';
import '../data/day_summary.dart';
import '../../../shared/utils/insights_range.dart';
import '../data/insights_service.dart';
import 'debrief_providers.dart';

/// Currently selected Insights time window (drives the range-scoped charts).
final insightsRangeProvider = StateProvider<InsightsRange>(
  (_) => InsightsRange.d30,
);

final insightsServiceProvider = Provider<InsightsService>(
  (_) => const InsightsService(),
);

/// `RangeSummary` for the selected window — reuses the existing composed
/// analytics provider so no new aggregation is needed.
final insightsRangeSummaryProvider = Provider<AsyncValue<RangeSummary>>((ref) {
  final range = ref.watch(insightsRangeProvider);
  final (start, end) = range.window(DateTime.now());
  return ref.watch(rangeSummaryProvider((start: start, end: end)));
});

/// Per-currency, bucketed finance insight for the selected window. Currencies
/// with in-range activity come first, then any others holding a balance.
final currencyInsightsProvider = Provider<AsyncValue<List<CurrencyInsight>>>((
  ref,
) {
  final range = ref.watch(insightsRangeProvider);
  final summaryA = ref.watch(insightsRangeSummaryProvider);
  final accountsA = ref.watch(fin.accountsStreamProvider);
  final currenciesA = ref.watch(fin.currenciesStreamProvider);
  final balancesA = ref.watch(fin.accountBalancesStreamProvider);

  final xs = <AsyncValue<Object?>>[summaryA, accountsA, currenciesA, balancesA];
  for (final a in xs) {
    if (a.isLoading && !a.hasValue) return const AsyncValue.loading();
  }
  for (final a in xs) {
    if (a.hasError) {
      return AsyncValue.error(a.error!, a.stackTrace ?? StackTrace.current);
    }
  }

  final summary = summaryA.value!;
  final accounts = accountsA.value ?? const <Account>[];
  final currencies = currenciesA.value ?? const <Currency>[];
  final balances = balancesA.value ?? const <String, double>{};
  final svc = ref.watch(insightsServiceProvider);
  final byId = {for (final c in currencies) c.id: c};

  final active = svc.activeCurrencyIds(summary);
  final withBalance = <String>{
    for (final a in accounts)
      if ((balances[a.id] ?? 0).abs() > 1e-9) a.currencyId,
  };
  final ordered = <String>[
    ...active,
    ...withBalance.where((c) => !active.contains(c)),
  ];

  final out = <CurrencyInsight>[
    for (final id in ordered)
      if (byId[id] != null)
        svc.buildCurrency(
          currency: byId[id]!,
          range: summary,
          bucket: range.bucket,
          accounts: accounts,
          balances: balances,
        ),
  ];
  return AsyncValue.data(out);
});

/// A 6-month forecast per currency (projection, runway, top categories). Stable
/// window independent of the range selector, since projection is inherently
/// forward-looking. Reuses [ForecastService.buildFinance] per currency.
final financeForecastsAllProvider = Provider<AsyncValue<List<FinanceForecast>>>(
  (ref) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 6, 1);
    final txA = ref.watch(
      fin.transactionsInRangeProvider((start: start, end: now.atEndOfDay)),
    );
    final accA = ref.watch(fin.accountsStreamProvider);
    final curA = ref.watch(fin.currenciesStreamProvider);
    final balA = ref.watch(fin.accountBalancesStreamProvider);
    final catA = ref.watch(fin.allCategoriesProvider);

    final xs = <AsyncValue<Object?>>[txA, accA, curA, balA, catA];
    for (final a in xs) {
      if (a.isLoading && !a.hasValue) return const AsyncValue.loading();
    }
    for (final a in xs) {
      if (a.hasError) {
        return AsyncValue.error(a.error!, a.stackTrace ?? StackTrace.current);
      }
    }

    final txs = txA.value ?? const <TransactionWithLegs>[];
    final accounts = accA.value ?? const <Account>[];
    final currencies = curA.value ?? const <Currency>[];
    final balances = balA.value ?? const <String, double>{};
    final categories = catA.value ?? const <Category>[];
    final svc = ref.watch(forecastServiceProvider);
    final byId = {for (final c in currencies) c.id: c};

    final totals = <String, double>{};
    for (final a in accounts) {
      totals.update(
        a.currencyId,
        (v) => v + (balances[a.id] ?? 0).abs(),
        ifAbsent: () => (balances[a.id] ?? 0).abs(),
      );
    }
    final ids = totals.keys.toList()
      ..sort((a, b) => (totals[b] ?? 0).compareTo(totals[a] ?? 0));

    final out = <FinanceForecast>[
      for (final id in ids)
        if (byId[id] != null)
          svc.buildFinance(
            txs: txs,
            accounts: accounts,
            currencies: currencies,
            balances: balances,
            categories: categories,
            now: now,
            forCurrencyId: id,
          ),
    ]..removeWhere((f) => !f.hasData);
    return AsyncValue.data(out);
  },
);

/// A category budget paired with this month's actual spend.
class BudgetActual {
  const BudgetActual({
    required this.category,
    required this.budget,
    required this.spent,
  });

  final Category category;
  final Budget budget;
  final double spent;

  double get fraction =>
      budget.amount <= 0 ? 0 : (spent / budget.amount).clamp(0.0, 1.0);
  double get rawFraction => budget.amount <= 0 ? 0 : spent / budget.amount;
  bool get over => spent > budget.amount;
  double get remaining => budget.amount - spent;
}

/// Budget-vs-actual for the current month, worst-offenders first. Mirrors the
/// spend math in `budgets_screen.dart`; self-empties when no budgets are set.
final budgetVsActualProvider = Provider<AsyncValue<List<BudgetActual>>>((ref) {
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final budgetsA = ref.watch(fin.budgetsStreamProvider);
  final catsA = ref.watch(fin.categoriesByKindProvider('expense'));
  final txA = ref.watch(
    fin.transactionsInRangeProvider((start: monthStart, end: now.atEndOfDay)),
  );

  final xs = <AsyncValue<Object?>>[budgetsA, catsA, txA];
  for (final a in xs) {
    if (a.isLoading && !a.hasValue) return const AsyncValue.loading();
  }
  for (final a in xs) {
    if (a.hasError) {
      return AsyncValue.error(a.error!, a.stackTrace ?? StackTrace.current);
    }
  }

  final budgets = budgetsA.value ?? const <Budget>[];
  final cats = catsA.value ?? const <Category>[];
  final txs = txA.value ?? const <TransactionWithLegs>[];
  final catById = {for (final c in cats) c.id: c};

  final spend = <String, double>{};
  for (final t in txs) {
    if (t.transaction.kind != 'expense') continue;
    final cid = t.transaction.categoryId;
    if (cid == null) continue;
    final amt = t.legs.fold<double>(0, (s, l) => s + l.amount.abs());
    spend.update(cid, (v) => v + amt, ifAbsent: () => amt);
  }

  final out = <BudgetActual>[
    for (final b in budgets)
      if (catById[b.categoryId] != null)
        BudgetActual(
          category: catById[b.categoryId]!,
          budget: b,
          spent: spend[b.categoryId] ?? 0,
        ),
  ]..sort((a, b) => b.rawFraction.compareTo(a.rawFraction));
  return AsyncValue.data(out);
});
