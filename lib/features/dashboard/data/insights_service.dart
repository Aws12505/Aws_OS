import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_ext.dart';
import 'day_summary.dart';
import '../../../shared/utils/insights_range.dart';

/// A single income/expense bucket (one day, or one month) for a currency.
class FlowPoint {
  const FlowPoint({
    required this.start,
    required this.label,
    required this.income,
    required this.expense,
  });

  final DateTime start;
  final String label;
  final double income;
  final double expense;

  double get net => income - expense;
}

/// Chart-ready finance insight for one currency over the selected range.
class CurrencyInsight {
  const CurrencyInsight({
    required this.currency,
    required this.points,
    required this.balanceSeries,
    required this.currentBalance,
  });

  final Currency currency;

  /// Income/expense buckets, ascending by time.
  final List<FlowPoint> points;

  /// End-of-bucket balance, ascending, aligned 1:1 with [points].
  final List<double> balanceSeries;
  final double currentBalance;

  double get totalIncome => points.fold(0.0, (s, p) => s + p.income);
  double get totalExpense => points.fold(0.0, (s, p) => s + p.expense);
  double get netFlow => totalIncome - totalExpense;
  bool get hasActivity => totalIncome > 0 || totalExpense > 0;

  List<String> get labels => [for (final p in points) p.label];
  List<double> get incomes => [for (final p in points) p.income];
  List<double> get expenses => [for (final p in points) p.expense];
  List<double> get nets => [for (final p in points) p.net];
}

/// Pure transforms from a [RangeSummary] (+ current balances) into the
/// per-currency, bucketed series the Insights charts render. Follows the same
/// "centralize the math out of widgets" convention as `AnalyticsService`.
class InsightsService {
  const InsightsService();

  /// Currency ids that saw income or expense over the range, busiest first.
  List<String> activeCurrencyIds(RangeSummary r) {
    final vol = <String, double>{};
    for (final d in r.days) {
      d.incomeByCurrency.forEach(
        (k, v) => vol.update(k, (x) => x + v, ifAbsent: () => v),
      );
      d.expenseByCurrency.forEach(
        (k, v) => vol.update(k, (x) => x + v, ifAbsent: () => v),
      );
    }
    final ids = vol.keys.where((k) => (vol[k] ?? 0) > 0).toList()
      ..sort((a, b) => (vol[b] ?? 0).compareTo(vol[a] ?? 0));
    return ids;
  }

  /// Bucket the range into daily or monthly income/expense points for a currency.
  List<FlowPoint> bucketFlow(
    RangeSummary r,
    InsightsBucket bucket,
    String currencyId,
  ) {
    if (bucket == InsightsBucket.daily) {
      final useWeekday = r.days.length <= 8;
      return [
        for (final d in r.days)
          FlowPoint(
            start: d.date,
            label: useWeekday
                ? DateFormat('E').format(d.date)
                : DateFormat('d/M').format(d.date),
            income: d.incomeByCurrency[currencyId] ?? 0,
            expense: d.expenseByCurrency[currencyId] ?? 0,
          ),
      ];
    }
    // Monthly: fold days into their month bucket.
    final inc = <String, double>{};
    final exp = <String, double>{};
    final starts = <String, DateTime>{};
    for (final d in r.days) {
      final ms = DateTime(d.date.year, d.date.month, 1);
      final key = ms.dayKey;
      starts[key] = ms;
      inc.update(
        key,
        (v) => v + (d.incomeByCurrency[currencyId] ?? 0),
        ifAbsent: () => d.incomeByCurrency[currencyId] ?? 0,
      );
      exp.update(
        key,
        (v) => v + (d.expenseByCurrency[currencyId] ?? 0),
        ifAbsent: () => d.expenseByCurrency[currencyId] ?? 0,
      );
    }
    final keys = starts.keys.toList()..sort();
    return [
      for (final k in keys)
        FlowPoint(
          start: starts[k]!,
          label: DateFormat('MMM').format(starts[k]!),
          income: inc[k] ?? 0,
          expense: exp[k] ?? 0,
        ),
    ];
  }

  /// Current total balance held in [currencyId] across its accounts.
  double currentBalanceFor(
    String currencyId,
    List<Account> accounts,
    Map<String, double> balances,
  ) {
    var total = 0.0;
    for (final a in accounts) {
      if (a.currencyId == currencyId) total += balances[a.id] ?? 0;
    }
    return total;
  }

  /// End-of-bucket balance reconstructed by walking [currentBalance] backward
  /// through each bucket's net. Approximate: reflects income/expense only (not
  /// transfers/exchanges), but consistent with the cash-flow shown alongside.
  List<double> balanceTrend(List<FlowPoint> points, double currentBalance) {
    final n = points.length;
    final series = List<double>.filled(n, 0);
    var running = currentBalance;
    for (var i = n - 1; i >= 0; i--) {
      series[i] = running;
      running -= points[i].net;
    }
    return series;
  }

  /// Assemble a full [CurrencyInsight] for one currency.
  CurrencyInsight buildCurrency({
    required Currency currency,
    required RangeSummary range,
    required InsightsBucket bucket,
    required List<Account> accounts,
    required Map<String, double> balances,
  }) {
    final points = bucketFlow(range, bucket, currency.id);
    final current = currentBalanceFor(currency.id, accounts, balances);
    return CurrencyInsight(
      currency: currency,
      points: points,
      balanceSeries: balanceTrend(points, current),
      currentBalance: current,
    );
  }
}

/// Compact human number: 1234 → "1.2K", 2_500_000 → "2.5M". Used for chart axes
/// and dense KPI tiles.
String compactNumber(double v) {
  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  if (a >= 1e9) return '$sign${(a / 1e9).toStringAsFixed(1)}B';
  if (a >= 1e6) return '$sign${(a / 1e6).toStringAsFixed(1)}M';
  if (a >= 1e3) return '$sign${(a / 1e3).toStringAsFixed(1)}K';
  if (a >= 100) return '$sign${a.toStringAsFixed(0)}';
  return '$sign${a == a.roundToDouble() ? a.toStringAsFixed(0) : a.toStringAsFixed(1)}';
}
