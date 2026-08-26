import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/notification_service.dart';
import '../data/finance_dao.dart';
import '../data/finance_repository.dart';
import '../data/recurrence_service.dart';

final financeDaoProvider = Provider<FinanceDao>((ref) {
  return FinanceDao(ref.watch(databaseProvider));
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(financeDaoProvider));
});

final currenciesStreamProvider = StreamProvider<List<Currency>>((ref) {
  return ref.watch(financeRepositoryProvider).watchCurrencies();
});

final accountsStreamProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(financeRepositoryProvider).watchAccounts();
});

/// Every account, including archived ones. A recurring entry's template can
/// reference an account that was archived after the recurrence was created —
/// confirming an occurrence must still be able to resolve it.
final allAccountsIncludingArchivedStreamProvider =
    StreamProvider<List<Account>>((ref) {
  return ref.watch(financeRepositoryProvider).watchAccounts(includeArchived: true);
});

final accountBalancesStreamProvider =
    StreamProvider<Map<String, double>>((ref) {
  return ref.watch(financeRepositoryProvider).watchAccountBalances();
});

final recentTransactionsStreamProvider =
    StreamProvider<List<TransactionWithLegs>>((ref) {
  return ref.watch(financeRepositoryProvider).watchRecentTransactions();
});

/// Transactions (with legs) within an inclusive date range — used by the
/// analytics/debrief layer for accurate day & trend aggregation.
final transactionsInRangeProvider = StreamProvider.family<
    List<TransactionWithLegs>, ({DateTime start, DateTime end})>((ref, range) {
  return ref
      .watch(financeDaoProvider)
      .watchTransactionsInRange(range.start, range.end);
});

/// Every transaction linked to [txId] (either direction), with legs —
/// powers the "linked transactions" management sheet and list-tile badge.
final linkedTransactionsProvider =
    StreamProvider.family<List<TransactionWithLegs>, String>((ref, txId) {
  return ref.watch(financeRepositoryProvider).watchLinkedTransactions(txId);
});

/// Wider pool than [recentTransactionsStreamProvider] — backs the "link to a
/// transaction" picker, which should be able to search further back than the
/// last 100 entries shown in the Activity tab.
final linkPickerTransactionsProvider =
    StreamProvider<List<TransactionWithLegs>>((ref) {
  return ref.watch(financeDaoProvider).watchRecentTransactions(limit: 300);
});

final exchangeRatesStreamProvider =
    StreamProvider<List<ExchangeRate>>((ref) {
  return ref.watch(financeRepositoryProvider).watchExchangeRates();
});

final categoriesByKindProvider =
    StreamProvider.family<List<Category>, String>((ref, kind) {
  return ref.watch(financeRepositoryProvider).watchCategoriesByKind(kind);
});

final allCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(financeRepositoryProvider).watchCategories();
});

final typesForCategoryProvider =
    StreamProvider.family<List<CategoryType>, String>((ref, categoryId) {
  return ref
      .watch(financeRepositoryProvider)
      .watchTypesForCategory(categoryId);
});

final allTypesProvider = StreamProvider<List<CategoryType>>((ref) {
  return ref.watch(financeRepositoryProvider).watchAllTypes();
});

final budgetsStreamProvider = StreamProvider<List<Budget>>((ref) {
  return ref.watch(financeDaoProvider).watchBudgets();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final recurrenceServiceProvider = Provider<RecurrenceService>((ref) {
  return RecurrenceService(
    ref.watch(financeDaoProvider),
    ref.watch(financeRepositoryProvider),
    ref.watch(notificationServiceProvider),
  );
});

final recurrencesStreamProvider = StreamProvider<List<Recurrence>>((ref) {
  return ref.watch(financeRepositoryProvider).watchRecurrences();
});

/// Pending scheduled occurrences whose due date is on or before today.
final pendingOccurrencesProvider =
    StreamProvider<List<ScheduledOccurrence>>((ref) {
  final endOfToday = DateTime.now().add(const Duration(days: 1));
  return ref
      .watch(financeRepositoryProvider)
      .watchPendingOccurrencesUpTo(endOfToday);
});

/// Every pending occurrence regardless of due date — the full "needs review"
/// queue. Each entry can be reviewed independently and in any order.
final allPendingOccurrencesProvider =
    StreamProvider<List<ScheduledOccurrence>>((ref) {
  return ref.watch(financeRepositoryProvider).watchAllPendingOccurrences();
});

/// Every occurrence (any status) belonging to a single recurrence, oldest
/// first — powers the per-recurrence review/history drill-down.
final occurrencesForRecurrenceProvider =
    StreamProvider.family<List<ScheduledOccurrence>, String>((ref, recurrenceId) {
  return ref
      .watch(financeRepositoryProvider)
      .watchOccurrencesForRecurrence(recurrenceId);
});

/// Pending occurrences within the next `days` (used by dashboard projections).
final pendingOccurrencesWindowProvider =
    StreamProvider.family<List<ScheduledOccurrence>, int>((ref, days) {
  final end = DateTime.now().add(Duration(days: days));
  return ref.watch(financeRepositoryProvider).watchPendingOccurrencesUpTo(end);
});

/// The most recent amount recorded against a category, and when.
///
/// Feeds the reference line in the income and expense sheet: entering a value
/// with no idea what it usually is means guessing, and the app already knows.
/// Absolute value, since expense legs are stored negative.
final lastAmountForCategoryProvider =
    Provider.family<({double amount, String currencyId, DateTime at})?, String>(
  (ref, categoryId) {
    final recent = ref.watch(recentTransactionsStreamProvider).value;
    if (recent == null) return null;
    for (final e in recent) {
      if (e.transaction.categoryId != categoryId) continue;
      if (e.legs.isEmpty) continue;
      final leg = e.legs.reduce(
        (a, b) => b.amount.abs() > a.amount.abs() ? b : a,
      );
      return (
        amount: leg.amount.abs(),
        currencyId: leg.currencyId,
        at: e.transaction.occurredAt,
      );
    }
    return null;
  },
);
