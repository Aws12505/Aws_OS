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

final accountBalancesStreamProvider =
    StreamProvider<Map<String, double>>((ref) {
  return ref.watch(financeRepositoryProvider).watchAccountBalances();
});

final recentTransactionsStreamProvider =
    StreamProvider<List<TransactionWithLegs>>((ref) {
  return ref.watch(financeRepositoryProvider).watchRecentTransactions();
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

/// Pending occurrences within the next `days` (used by dashboard projections).
final pendingOccurrencesWindowProvider =
    StreamProvider.family<List<ScheduledOccurrence>, int>((ref, days) {
  final end = DateTime.now().add(Duration(days: days));
  return ref.watch(financeRepositoryProvider).watchPendingOccurrencesUpTo(end);
});
