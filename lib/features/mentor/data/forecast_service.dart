import 'dart:math' as math;

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_ext.dart';
import '../../finance/data/finance_dao.dart';

/// The mentor domains the user can consult.
enum MentorKind { finance, gym, productivity }

extension MentorKindX on MentorKind {
  String get title => switch (this) {
        MentorKind.finance => 'Finance mentor',
        MentorKind.gym => 'Gym mentor',
        MentorKind.productivity => 'Productivity mentor',
      };

  String get tagline => switch (this) {
        MentorKind.finance => 'Cash-flow analysis & forecasts',
        MentorKind.gym => 'Training & body-trend coaching',
        MentorKind.productivity => 'Focus & follow-through',
      };
}

class MonthlyFlow {
  const MonthlyFlow({
    required this.month,
    required this.income,
    required this.expense,
  });
  final DateTime month;
  final double income;
  final double expense;
  double get net => income - expense;
}

class CategorySpend {
  const CategorySpend(this.name, this.amount);
  final String name;
  final double amount;
}

class FinanceForecast {
  const FinanceForecast({
    required this.hasData,
    required this.currencyCode,
    required this.currencySymbol,
    required this.decimals,
    required this.currentBalance,
    required this.months,
    required this.avgMonthlyNet,
    required this.projected,
    required this.runwayMonths,
    required this.topCategories,
  });

  final bool hasData;
  final String currencyCode;
  final String currencySymbol;
  final int decimals;
  final double currentBalance;
  final List<MonthlyFlow> months; // ascending
  final double avgMonthlyNet;
  final Map<int, double> projected; // months-ahead -> projected balance
  final double? runwayMonths; // null unless burning down
  final List<CategorySpend> topCategories;

  bool get growing => avgMonthlyNet >= 0;

  static const empty = FinanceForecast(
    hasData: false,
    currencyCode: '',
    currencySymbol: '',
    decimals: 2,
    currentBalance: 0,
    months: [],
    avgMonthlyNet: 0,
    projected: {},
    runwayMonths: null,
    topCategories: [],
  );
}

class MeasurementTrend {
  const MeasurementTrend({
    required this.name,
    required this.unit,
    required this.first,
    required this.latest,
    required this.slopePerWeek,
    required this.projected4w,
    required this.count,
    required this.series,
  });
  final String name;
  final String unit;
  final double first;
  final double latest;
  final double slopePerWeek;
  final double projected4w;
  final int count;
  final List<double> series;
  double get change => latest - first;
}

class GymForecast {
  const GymForecast({
    required this.hasData,
    required this.totalSessions,
    required this.weeks,
    required this.sessionsPerWeek,
    required this.currentWeekStreak,
    required this.lastSessionDaysAgo,
    required this.measurements,
  });
  final bool hasData;
  final int totalSessions;
  final int weeks;
  final double sessionsPerWeek;
  final int currentWeekStreak;
  final int? lastSessionDaysAgo;
  final List<MeasurementTrend> measurements;

  static const empty = GymForecast(
    hasData: false,
    totalSessions: 0,
    weeks: 0,
    sessionsPerWeek: 0,
    currentWeekStreak: 0,
    lastSessionDaysAgo: null,
    measurements: [],
  );
}

class ProductivityForecast {
  const ProductivityForecast({
    required this.hasData,
    required this.windowDays,
    required this.due,
    required this.done,
    required this.completionRate,
    required this.overdue,
    required this.dailyCompletion,
    required this.slopePerDay,
  });
  final bool hasData;
  final int windowDays;
  final int due;
  final int done;
  final double completionRate;
  final int overdue;
  final List<double> dailyCompletion;
  final double slopePerDay;

  static const empty = ProductivityForecast(
    hasData: false,
    windowDays: 30,
    due: 0,
    done: 0,
    completionRate: 0,
    overdue: 0,
    dailyCompletion: [],
    slopePerDay: 0,
  );
}

/// Pure, on-device analysis + forecasting over already-loaded data. The output
/// is shown directly and also fed to the AI mentors as grounding context.
class ForecastService {
  const ForecastService();

  FinanceForecast buildFinance({
    required List<TransactionWithLegs> txs,
    required List<Account> accounts,
    required List<Currency> currencies,
    required Map<String, double> balances,
    required List<Category> categories,
    required DateTime now,
    int monthsBack = 6,
  }) {
    final totals = <String, double>{};
    for (final a in accounts) {
      totals.update(a.currencyId, (v) => v + (balances[a.id] ?? 0),
          ifAbsent: () => balances[a.id] ?? 0);
    }
    if (totals.isEmpty) return FinanceForecast.empty;
    final primary = totals.entries
        .reduce((a, b) => a.value.abs() >= b.value.abs() ? a : b)
        .key;
    final cur = {for (final c in currencies) c.id: c}[primary];
    final catName = {for (final c in categories) c.id: c.name};

    final months = <MonthlyFlow>[];
    for (var i = monthsBack; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final next = DateTime(m.year, m.month + 1, 1);
      var inc = 0.0, exp = 0.0;
      for (final t in txs) {
        final at = t.transaction.occurredAt;
        if (at.isBefore(m) || !at.isBefore(next)) continue;
        for (final leg in t.legs) {
          if (leg.currencyId != primary) continue;
          final amt = leg.amount.abs();
          if (t.transaction.kind == 'income') {
            inc += amt;
          } else if (t.transaction.kind == 'expense') {
            exp += amt;
          }
        }
      }
      months.add(MonthlyFlow(month: m, income: inc, expense: exp));
    }
    // Average over completed months (exclude the current partial month).
    final completed = months.length > 1
        ? months.sublist(0, months.length - 1)
        : months;
    final avg = completed.isEmpty
        ? 0.0
        : completed.map((m) => m.net).reduce((a, b) => a + b) /
            completed.length;
    final balance = totals[primary] ?? 0;
    final projected = {
      for (final n in [1, 3, 6]) n: balance + avg * n,
    };
    final runway = avg < 0 && balance > 0 ? balance / -avg : null;

    // Top expense categories over the window, primary currency.
    final perCat = <String, double>{};
    final windowStart = DateTime(now.year, now.month - monthsBack, 1);
    for (final t in txs) {
      if (t.transaction.kind != 'expense') continue;
      if (t.transaction.occurredAt.isBefore(windowStart)) continue;
      for (final leg in t.legs) {
        if (leg.currencyId != primary) continue;
        final id = t.transaction.categoryId ?? '';
        perCat.update(id, (v) => v + leg.amount.abs(),
            ifAbsent: () => leg.amount.abs());
      }
    }
    final topCats = perCat.entries
        .map((e) => CategorySpend(
              e.key.isEmpty ? 'Uncategorized' : (catName[e.key] ?? 'Uncategorized'),
              e.value,
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final hasData =
        balance != 0 || months.any((m) => m.income > 0 || m.expense > 0);

    return FinanceForecast(
      hasData: hasData,
      currencyCode: cur?.code ?? '',
      currencySymbol: cur?.symbol ?? cur?.code ?? '',
      decimals: cur?.decimalPlaces ?? 2,
      currentBalance: balance,
      months: months,
      avgMonthlyNet: avg,
      projected: projected,
      runwayMonths: runway,
      topCategories: topCats.take(5).toList(),
    );
  }

  GymForecast buildGym({
    required List<DaySession> sessions,
    required List<MeasurementEntry> entries,
    required List<MeasurementValue> values,
    required List<MeasurementType> types,
    required DateTime now,
    int weeksBack = 8,
  }) {
    final windowStart = now.addDays(-7 * weeksBack);
    final recent =
        sessions.where((s) => !s.playedAt.isBefore(windowStart)).length;
    final perWeek = recent / weeksBack;
    final lastDays = sessions.isEmpty
        ? null
        : now.difference(sessions.first.playedAt).inDays; // sessions desc

    // Consecutive weeks (ending this week) with >=1 session.
    final weekKeys = {for (final s in sessions) _weekKey(s.playedAt)};
    var streak = 0;
    var cursor = now;
    for (var i = 0; i < 260; i++) {
      if (weekKeys.contains(_weekKey(cursor))) {
        streak++;
        cursor = cursor.addDays(-7);
      } else {
        break;
      }
    }

    final byEntry = <String, List<MeasurementValue>>{};
    for (final v in values) {
      byEntry.putIfAbsent(v.entryId, () => []).add(v);
    }
    final entriesAsc = entries.toList()
      ..sort((a, b) => a.takenAt.compareTo(b.takenAt));

    final trends = <MeasurementTrend>[];
    for (final t in types) {
      final pts = <MapEntry<DateTime, double>>[];
      for (final e in entriesAsc) {
        for (final v in (byEntry[e.id] ?? const [])) {
          if (v.typeId == t.id) pts.add(MapEntry(e.takenAt, v.value));
        }
      }
      if (pts.isEmpty) continue;
      final series = pts.map((p) => p.value).toList();
      final slope = _slopePerWeek(pts);
      trends.add(MeasurementTrend(
        name: t.name,
        unit: t.unit ?? '',
        first: series.first,
        latest: series.last,
        slopePerWeek: slope,
        projected4w: series.last + slope * 4,
        count: series.length,
        series: series,
      ));
    }

    return GymForecast(
      hasData: sessions.isNotEmpty || trends.isNotEmpty,
      totalSessions: recent,
      weeks: weeksBack,
      sessionsPerWeek: perWeek,
      currentWeekStreak: streak,
      lastSessionDaysAgo: lastDays,
      measurements: trends,
    );
  }

  ProductivityForecast buildProductivity({
    required List<Task> tasks,
    required DateTime now,
    int windowDays = 30,
  }) {
    final today = now.atStartOfDay;
    final daily = <double>[];
    var totalDue = 0, totalDone = 0;
    for (var i = windowDays - 1; i >= 0; i--) {
      final day = today.addDays(-i);
      final due = tasks.where((t) =>
          (t.dueAt != null && t.dueAt!.isSameDay(day)) ||
          (t.deadlineAt != null && t.deadlineAt!.isSameDay(day)));
      final d = due.length;
      final done = due.where((t) => t.isCompleted).length;
      totalDue += d;
      totalDone += done;
      daily.add(d == 0 ? 0 : done / d);
    }
    final overdue = tasks.where((t) {
      if (t.isCompleted) return false;
      final ref = t.deadlineAt ?? t.dueAt;
      return ref != null && ref.isBefore(today);
    }).length;

    return ProductivityForecast(
      hasData: totalDue > 0 || overdue > 0,
      windowDays: windowDays,
      due: totalDue,
      done: totalDone,
      completionRate: totalDue == 0 ? 0 : totalDone / totalDue,
      overdue: overdue,
      dailyCompletion: daily,
      slopePerDay: _slope(daily),
    );
  }

  double _slopePerWeek(List<MapEntry<DateTime, double>> pts) {
    if (pts.length < 2) return 0;
    final t0 = pts.first.key;
    final xs = pts.map((p) => p.key.difference(t0).inHours / (24 * 7)).toList();
    final ys = pts.map((p) => p.value).toList();
    return _regress(xs, ys);
  }

  double _slope(List<double> ys) {
    if (ys.length < 2) return 0;
    final xs = [for (var i = 0; i < ys.length; i++) i.toDouble()];
    return _regress(xs, ys);
  }

  double _regress(List<double> xs, List<double> ys) {
    final n = xs.length;
    final mx = xs.reduce((a, b) => a + b) / n;
    final my = ys.reduce((a, b) => a + b) / n;
    var num = 0.0, den = 0.0;
    for (var i = 0; i < n; i++) {
      num += (xs[i] - mx) * (ys[i] - my);
      den += (xs[i] - mx) * (xs[i] - mx);
    }
    return den == 0 ? 0 : num / den;
  }

  String _weekKey(DateTime d) {
    final monday = d.addDays(-((d.weekday + 6) % 7));
    return monday.dayKey;
  }
}

double safeMax(Iterable<double> xs, [double fallback = 1]) {
  final list = xs.toList();
  if (list.isEmpty) return fallback;
  return list.reduce(math.max);
}
