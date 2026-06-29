import '../../../core/db/app_database.dart';
import '../../../core/utils/date_ext.dart';
import '../../finance/data/finance_dao.dart';
import 'day_summary.dart';

/// Pure aggregation over already-loaded feature lists. Centralizes the per-day
/// math that previously lived inside dashboard widgets so the dashboard,
/// debrief and analytics views all share one source of truth.
class AnalyticsService {
  const AnalyticsService();

  DaySummary buildDay({
    required DateTime date,
    required List<Task> allTasks,
    required List<TransactionWithLegs> txs,
    required List<Account> accounts,
    required List<Category> categories,
    required List<DaySession> sessions,
    required List<Note> notes,
    DebriefEntry? debrief,
    List<String> recentDebriefKeys = const [],
  }) {
    final day = date.atStartOfDay;
    final currencyOf = {for (final a in accounts) a.id: a.currencyId};
    final catName = {for (final c in categories) c.id: c.name};

    // Tasks due (or with a deadline) on this day.
    final dueTasks = allTasks.where((t) =>
        (t.dueAt != null && t.dueAt!.isSameDay(day)) ||
        (t.deadlineAt != null && t.deadlineAt!.isSameDay(day)));
    final tasksDue = dueTasks.length;
    final tasksDone = dueTasks.where((t) => t.isCompleted).length;

    // Money for the day, grouped by the account's currency.
    final income = <String, double>{};
    final expense = <String, double>{};
    final perCat = <String, double>{}; // categoryId ('' = none) -> total
    var txCount = 0;
    for (final t in txs) {
      if (!t.transaction.occurredAt.isSameDay(day)) continue;
      txCount++;
      final kind = t.transaction.kind;
      for (final leg in t.legs) {
        final cur = currencyOf[leg.accountId] ?? '?';
        final amt = leg.amount.abs();
        if (kind == 'income') {
          income.update(cur, (v) => v + amt, ifAbsent: () => amt);
        } else if (kind == 'expense') {
          expense.update(cur, (v) => v + amt, ifAbsent: () => amt);
          final catId = t.transaction.categoryId ?? '';
          perCat.update(catId, (v) => v + amt, ifAbsent: () => amt);
        }
      }
    }
    final topCats = perCat.entries
        .map((e) => CategoryTotal(
              categoryId: e.key,
              name: e.key.isEmpty
                  ? 'Uncategorized'
                  : (catName[e.key] ?? 'Uncategorized'),
              amount: e.value,
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final sessionCount =
        sessions.where((s) => s.playedAt.isSameDay(day)).length;
    final notesCount = notes.where((n) => n.occurredAt.isSameDay(day)).length;

    return DaySummary(
      date: day,
      tasksDue: tasksDue,
      tasksDone: tasksDone,
      incomeByCurrency: income,
      expenseByCurrency: expense,
      topExpenseCategories: topCats.take(6).toList(),
      transactionCount: txCount,
      workedOut: sessionCount > 0,
      sessionCount: sessionCount,
      notesCount: notesCount,
      debrief: debrief,
      taskStreak: _taskStreak(day, allTasks),
      debriefStreak: _debriefStreak(day, recentDebriefKeys),
    );
  }

  RangeSummary buildRange({
    required DateTime start,
    required DateTime end,
    required List<Task> allTasks,
    required List<TransactionWithLegs> txs,
    required List<Account> accounts,
    required List<Category> categories,
    required List<DaySession> sessions,
    required List<Note> notes,
    required List<DebriefEntry> debriefs,
  }) {
    final byKey = {for (final d in debriefs) d.dayKey: d};
    final keys = debriefs.map((d) => d.dayKey).toList();
    final days = <DaySummary>[];
    final last = end.atStartOfDay;
    var cursor = start.atStartOfDay;
    for (var i = 0; i < 400 && !cursor.isAfter(last); i++) {
      days.add(buildDay(
        date: cursor,
        allTasks: allTasks,
        txs: txs,
        accounts: accounts,
        categories: categories,
        sessions: sessions,
        notes: notes,
        debrief: byKey[cursor.dayKey],
        recentDebriefKeys: keys,
      ));
      cursor = cursor.addDays(1);
    }
    return RangeSummary(start: start.atStartOfDay, end: last, days: days);
  }

  /// Consecutive days ending at [day] that had ≥1 task due and all completed.
  int _taskStreak(DateTime day, List<Task> allTasks) {
    var streak = 0;
    var cursor = day;
    for (var i = 0; i < 365; i++) {
      final due = allTasks.where((t) =>
          (t.dueAt != null && t.dueAt!.isSameDay(cursor)) ||
          (t.deadlineAt != null && t.deadlineAt!.isSameDay(cursor)));
      final dueCount = due.length;
      if (dueCount == 0) break;
      if (due.where((t) => t.isCompleted).length < dueCount) break;
      streak++;
      cursor = cursor.addDays(-1);
    }
    return streak;
  }

  /// Consecutive days ending at [day] that have a debrief entry.
  int _debriefStreak(DateTime day, List<String> keys) {
    final set = keys.toSet();
    var streak = 0;
    var cursor = day;
    for (var i = 0; i < 365; i++) {
      if (!set.contains(cursor.dayKey)) break;
      streak++;
      cursor = cursor.addDays(-1);
    }
    return streak;
  }
}
