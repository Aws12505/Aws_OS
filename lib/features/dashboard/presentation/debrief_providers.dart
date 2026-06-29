import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/date_ext.dart';
import '../../finance/presentation/providers.dart' as fin;
import '../../gym/presentation/providers.dart' as gym;
import '../../notes/presentation/providers.dart' as notes;
import '../../tasks/presentation/providers.dart' as tasks;
import '../data/analytics_service.dart';
import '../data/day_summary.dart';
import '../data/debrief_dao.dart';
import '../data/debrief_repository.dart';

final debriefDaoProvider = Provider<DebriefDao>((ref) {
  return DebriefDao(ref.watch(databaseProvider));
});

final debriefRepositoryProvider = Provider<DebriefRepository>((ref) {
  return DebriefRepository(ref.watch(debriefDaoProvider));
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return const AnalyticsService();
});

/// The debrief row for a given day (or null).
final debriefForDayProvider =
    StreamProvider.family<DebriefEntry?, DateTime>((ref, date) {
  return ref.watch(debriefRepositoryProvider).watchEntry(date);
});

/// Debrief rows within an inclusive range — for streaks & trends.
final debriefRangeProvider = StreamProvider.family<List<DebriefEntry>,
    ({DateTime start, DateTime end})>((ref, range) {
  return ref
      .watch(debriefRepositoryProvider)
      .watchRange(range.start, range.end);
});

/// Full computed summary for a single day. Composes the existing feature
/// streams + the debrief row through [AnalyticsService] and surfaces a single
/// [AsyncValue] so screens get loading/error handling for free.
final daySummaryProvider =
    Provider.family<AsyncValue<DaySummary>, DateTime>((ref, date) {
  final tasksA = ref.watch(tasks.allTasksStreamProvider);
  final txA = ref.watch(fin.transactionsInRangeProvider(
      (start: date.atStartOfDay, end: date.atEndOfDay)));
  final accountsA = ref.watch(fin.accountsStreamProvider);
  final catsA = ref.watch(fin.allCategoriesProvider);
  final sessionsA = ref.watch(gym.allSessionsStreamProvider);
  final notesA = ref.watch(notes.notesStreamProvider);
  final debriefA = ref.watch(debriefForDayProvider(date));
  final recentA = ref.watch(
      debriefRangeProvider((start: date.addDays(-60), end: date)));

  final asyncs = <AsyncValue<Object?>>[
    tasksA, txA, accountsA, catsA, sessionsA, notesA, debriefA, recentA,
  ];
  for (final a in asyncs) {
    if (a.isLoading && !a.hasValue) return const AsyncValue.loading();
  }
  for (final a in asyncs) {
    if (a.hasError) {
      return AsyncValue.error(a.error!, a.stackTrace ?? StackTrace.current);
    }
  }

  final summary = ref.watch(analyticsServiceProvider).buildDay(
        date: date,
        allTasks: tasksA.value ?? const [],
        txs: txA.value ?? const [],
        accounts: accountsA.value ?? const [],
        categories: catsA.value ?? const [],
        sessions: sessionsA.value ?? const [],
        notes: notesA.value ?? const [],
        debrief: debriefA.value,
        recentDebriefKeys:
            (recentA.value ?? const <DebriefEntry>[]).map((e) => e.dayKey).toList(),
      );
  return AsyncValue.data(summary);
});

/// Range (week/month) summary for trend charts.
final rangeSummaryProvider = Provider.family<AsyncValue<RangeSummary>,
    ({DateTime start, DateTime end})>((ref, range) {
  final tasksA = ref.watch(tasks.allTasksStreamProvider);
  final txA = ref.watch(fin.transactionsInRangeProvider(
      (start: range.start.atStartOfDay, end: range.end.atEndOfDay)));
  final accountsA = ref.watch(fin.accountsStreamProvider);
  final catsA = ref.watch(fin.allCategoriesProvider);
  final sessionsA = ref.watch(gym.allSessionsStreamProvider);
  final notesA = ref.watch(notes.notesStreamProvider);
  final debriefA = ref.watch(debriefRangeProvider(range));

  final asyncs = <AsyncValue<Object?>>[
    tasksA, txA, accountsA, catsA, sessionsA, notesA, debriefA,
  ];
  for (final a in asyncs) {
    if (a.isLoading && !a.hasValue) return const AsyncValue.loading();
  }
  for (final a in asyncs) {
    if (a.hasError) {
      return AsyncValue.error(a.error!, a.stackTrace ?? StackTrace.current);
    }
  }

  final summary = ref.watch(analyticsServiceProvider).buildRange(
        start: range.start,
        end: range.end,
        allTasks: tasksA.value ?? const [],
        txs: txA.value ?? const [],
        accounts: accountsA.value ?? const [],
        categories: catsA.value ?? const [],
        sessions: sessionsA.value ?? const [],
        notes: notesA.value ?? const [],
        debriefs: debriefA.value ?? const [],
      );
  return AsyncValue.data(summary);
});
