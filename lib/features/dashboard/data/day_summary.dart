import '../../../core/db/app_database.dart';

/// A single category's expense total for a day or range.
class CategoryTotal {
  const CategoryTotal({
    required this.categoryId,
    required this.name,
    required this.amount,
  });

  final String categoryId;
  final String name;
  final double amount;
}

/// Rich, computed summary of one day across every domain. A pure value object
/// produced by [AnalyticsService]; the only DB type it carries is the optional
/// debrief row.
class DaySummary {
  const DaySummary({
    required this.date,
    required this.tasksDue,
    required this.tasksDone,
    required this.incomeByCurrency,
    required this.expenseByCurrency,
    required this.topExpenseCategories,
    required this.transactionCount,
    required this.workedOut,
    required this.sessionCount,
    required this.notesCount,
    this.debrief,
    this.taskStreak = 0,
    this.debriefStreak = 0,
  });

  final DateTime date;
  final int tasksDue;
  final int tasksDone;

  /// currencyId -> summed amount for the day.
  final Map<String, double> incomeByCurrency;
  final Map<String, double> expenseByCurrency;

  /// Expense totals per category, descending.
  final List<CategoryTotal> topExpenseCategories;
  final int transactionCount;

  final bool workedOut;
  final int sessionCount;
  final int notesCount;

  final DebriefEntry? debrief;
  final int taskStreak;
  final int debriefStreak;

  double get taskCompletion => tasksDue == 0 ? 0 : tasksDone / tasksDue;

  bool get hasActivity =>
      tasksDue > 0 || transactionCount > 0 || workedOut || notesCount > 0;

  bool get hasDebrief => debrief != null;

  Map<String, double> get netByCurrency {
    final keys = {...incomeByCurrency.keys, ...expenseByCurrency.keys};
    return {
      for (final k in keys)
        k: (incomeByCurrency[k] ?? 0) - (expenseByCurrency[k] ?? 0),
    };
  }
}

/// Aggregated summary across a date range (week/month) for trend charts.
class RangeSummary {
  const RangeSummary({
    required this.start,
    required this.end,
    required this.days,
  });

  final DateTime start;
  final DateTime end;

  /// One [DaySummary] per day, ascending by date.
  final List<DaySummary> days;

  int get totalTasksDone => days.fold(0, (s, d) => s + d.tasksDone);
  int get totalTasksDue => days.fold(0, (s, d) => s + d.tasksDue);
  int get totalWorkouts => days.where((d) => d.workedOut).length;
  int get daysWithNotes => days.where((d) => d.notesCount > 0).length;
  int get daysWithDebrief => days.where((d) => d.hasDebrief).length;

  double get avgTaskCompletion {
    final withTasks = days.where((d) => d.tasksDue > 0).toList();
    if (withTasks.isEmpty) return 0;
    return withTasks.map((d) => d.taskCompletion).reduce((a, b) => a + b) /
        withTasks.length;
  }

  double get avgMood => _avg(days.map((d) => d.debrief?.mood));
  double get avgEnergy => _avg(days.map((d) => d.debrief?.energy));

  static double _avg(Iterable<int?> values) {
    final present = values.whereType<int>().toList();
    if (present.isEmpty) return 0;
    return present.reduce((a, b) => a + b) / present.length;
  }

  Map<String, double> get netByCurrency {
    final out = <String, double>{};
    for (final d in days) {
      d.netByCurrency.forEach(
        (k, v) => out.update(k, (x) => x + v, ifAbsent: () => v),
      );
    }
    return out;
  }
}
