import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/tables/_syncable.dart';
import 'finance_dao.dart';

/// One signed line on a transaction. Positive = inflow into `accountId`,
/// negative = outflow.
class TxLegDraft {
  const TxLegDraft({
    required this.accountId,
    required this.currencyId,
    required this.amount,
  });
  final String accountId;
  final String currencyId;
  final double amount;
}

class FinanceRepository {
  FinanceRepository(this.dao);

  final FinanceDao dao;

  // -- Currencies / Accounts pass-throughs ---------------------------------

  Stream<List<Currency>> watchCurrencies() => dao.watchCurrencies();
  Future<List<Currency>> getCurrencies() => dao.getCurrencies();
  Future<Currency?> getCurrency(String id) => dao.getCurrency(id);

  Future<void> saveCurrency({
    String? id,
    required String code,
    required String symbol,
    int decimalPlaces = 2,
    bool isActive = true,
    int sortOrder = 0,
  }) {
    return dao.upsertCurrency(CurrenciesCompanion(
      id: id == null ? const Value.absent() : Value(id),
      code: Value(code),
      symbol: Value(symbol),
      decimalPlaces: Value(decimalPlaces),
      isActive: Value(isActive),
      sortOrder: Value(sortOrder),
    ));
  }

  Future<void> deleteCurrency(String id) => dao.deleteCurrency(id);

  Stream<List<Account>> watchAccounts({bool includeArchived = false}) =>
      dao.watchAccounts(includeArchived: includeArchived);
  Future<List<Account>> getAccounts() => dao.getAccounts();
  Future<Account?> getAccount(String id) => dao.getAccount(id);

  Future<void> saveAccount({
    String? id,
    required String name,
    required String currencyId,
    String kind = 'cash',
    int? color,
    String? icon,
    bool archived = false,
    int sortOrder = 0,
    String? note,
  }) {
    return dao.upsertAccount(AccountsCompanion(
      id: id == null ? const Value.absent() : Value(id),
      name: Value(name),
      currencyId: Value(currencyId),
      kind: Value(kind),
      color: Value(color),
      icon: Value(icon),
      archived: Value(archived),
      sortOrder: Value(sortOrder),
      note: Value(note),
    ));
  }

  Future<void> deleteAccount(String id) => dao.deleteAccount(id);

  // -- Categories & Types --------------------------------------------------

  Stream<List<Category>> watchCategoriesByKind(String kind) =>
      dao.watchCategoriesByKind(kind);
  Stream<List<Category>> watchCategories() => dao.watchCategories();
  Stream<List<CategoryType>> watchTypesForCategory(String categoryId) =>
      dao.watchTypesForCategory(categoryId);
  Stream<List<CategoryType>> watchAllTypes() => dao.watchAllTypes();

  Future<void> saveCategory({
    String? id,
    required String kind,
    required String name,
    int? color,
    String? icon,
    int sortOrder = 0,
  }) {
    return dao.upsertCategory(CategoriesCompanion(
      id: id == null ? const Value.absent() : Value(id),
      kind: Value(kind),
      name: Value(name),
      color: Value(color),
      icon: Value(icon),
      sortOrder: Value(sortOrder),
    ));
  }

  Future<void> deleteCategory(String id) => dao.deleteCategory(id);

  Future<void> saveType({
    String? id,
    required String categoryId,
    required String name,
    int sortOrder = 0,
  }) {
    return dao.upsertType(CategoryTypesCompanion(
      id: id == null ? const Value.absent() : Value(id),
      categoryId: Value(categoryId),
      name: Value(name),
      sortOrder: Value(sortOrder),
    ));
  }

  Future<void> deleteType(String id) => dao.deleteType(id);

  // -- Recurrences ---------------------------------------------------------

  Stream<List<Recurrence>> watchRecurrences() => dao.watchRecurrences();
  Future<Recurrence?> getRecurrence(String id) => dao.getRecurrence(id);
  Stream<List<ScheduledOccurrence>> watchPendingOccurrencesUpTo(
          DateTime end) =>
      dao.watchPendingOccurrencesUpTo(end);
  Stream<List<ScheduledOccurrence>> watchAllPendingOccurrences() =>
      dao.watchAllPendingOccurrences();
  Stream<List<ScheduledOccurrence>> watchOccurrencesForRecurrence(String id) =>
      dao.watchOccurrencesForRecurrence(id);

  /// Save (insert or replace) a recurring entry. The caller computes the
  /// `nextDueAt` value or leaves it null — the recurrence service will set
  /// it after materializing the queue.
  Future<Recurrence> saveRecurrence({
    String? id,
    required String kind,
    required String ruleJson,
    required String templateLegsJson,
    String? categoryId,
    String? typeId,
    String? noteTemplate,
    required DateTime startDate,
    DateTime? endedAt,
  }) {
    return dao.upsertRecurrenceReturning(RecurrencesCompanion(
      id: id == null ? const Value.absent() : Value(id),
      kind: Value(kind),
      ruleJson: Value(ruleJson),
      templateLegsJson: Value(templateLegsJson),
      categoryId: Value(categoryId),
      typeId: Value(typeId),
      noteTemplate: Value(noteTemplate),
      startDate: Value(startDate),
      endedAt: Value(endedAt),
    ));
  }

  Future<void> deleteRecurrence(String id) async {
    await dao.deleteOccurrencesForRecurrence(id);
    await dao.deleteRecurrence(id);
  }

  Stream<Map<String, double>> watchAccountBalances() =>
      dao.watchAccountBalances();

  Stream<List<TransactionWithLegs>> watchRecentTransactions({int limit = 100}) =>
      dao.watchRecentTransactions(limit: limit);

  Stream<List<ExchangeRate>> watchExchangeRates({int limit = 200}) =>
      dao.watchExchangeRates(limit: limit);

  // -- Higher-level operations --------------------------------------------

  /// Single- or multi-leg income/expense entry. Legs may span currencies and
  /// accounts; the kind ('income' or 'expense') is recorded on the parent
  /// row for filtering, while balance impact is fully driven by leg signs.
  Future<String> recordIncomeOrExpense({
    required String kind, // 'income' | 'expense'
    required DateTime occurredAt,
    required List<TxLegDraft> legs,
    String? note,
    String? categoryId,
    String? typeId,
    String? recurrenceId,
    String? scheduledOccurrenceId,
  }) {
    assert(kind == 'income' || kind == 'expense');
    final txId = newUuid();
    return dao.insertTransaction(
      tx: TransactionsCompanion(
        id: Value(txId),
        kind: Value(kind),
        occurredAt: Value(occurredAt),
        note: Value(note),
        categoryId: Value(categoryId),
        typeId: Value(typeId),
        recurrenceId: Value(recurrenceId),
        scheduledOccurrenceId: Value(scheduledOccurrenceId),
      ),
      legs: [
        for (final l in legs)
          TransactionLegsCompanion(
            accountId: Value(l.accountId),
            currencyId: Value(l.currencyId),
            amount: Value(l.amount),
          ),
      ],
    );
  }

  /// Same-currency transfer from one account to another. Records two legs:
  /// -amount on source, +amount on destination.
  Future<String> recordTransfer({
    required String fromAccountId,
    required String toAccountId,
    required String currencyId,
    required double amount, // positive
    required DateTime occurredAt,
    String? note,
  }) {
    assert(amount > 0);
    return dao.insertTransaction(
      tx: TransactionsCompanion(
        kind: const Value('transfer'),
        occurredAt: Value(occurredAt),
        note: Value(note),
      ),
      legs: [
        TransactionLegsCompanion(
          accountId: Value(fromAccountId),
          currencyId: Value(currencyId),
          amount: Value(-amount),
        ),
        TransactionLegsCompanion(
          accountId: Value(toAccountId),
          currencyId: Value(currencyId),
          amount: Value(amount),
        ),
      ],
    );
  }

  /// Cross-currency exchange. Caller supplies from/to amounts; the rate is
  /// the multiplier `toAmount / fromAmount`. Writes two legs (negative on
  /// source, positive on destination) and an `exchange_rates` history row.
  Future<String> recordExchange({
    required String fromAccountId,
    required String fromCurrencyId,
    required double fromAmount, // positive
    required String toAccountId,
    required String toCurrencyId,
    required double toAmount, // positive
    required DateTime occurredAt,
    String? note,
  }) {
    assert(fromAmount > 0 && toAmount > 0);
    final rate = toAmount / fromAmount;
    return dao.insertTransaction(
      tx: TransactionsCompanion(
        kind: const Value('exchange'),
        occurredAt: Value(occurredAt),
        note: Value(note),
      ),
      legs: [
        TransactionLegsCompanion(
          accountId: Value(fromAccountId),
          currencyId: Value(fromCurrencyId),
          amount: Value(-fromAmount),
        ),
        TransactionLegsCompanion(
          accountId: Value(toAccountId),
          currencyId: Value(toCurrencyId),
          amount: Value(toAmount),
        ),
      ],
      rate: ExchangeRatesCompanion(
        fromCurrencyId: Value(fromCurrencyId),
        toCurrencyId: Value(toCurrencyId),
        rate: Value(rate),
        occurredAt: Value(occurredAt),
      ),
    );
  }

  Future<void> deleteTransaction(String id) => dao.deleteTransaction(id);

  Future<TransactionWithLegs?> getTransactionWithLegs(String id) =>
      dao.getTransactionWithLegs(id);

  // -- Linking --------------------------------------------------------------

  /// Links two transactions together — undirected and many-to-many, so any
  /// transaction can end up linked to any number of others regardless of
  /// kind (e.g. an expense linked to several separate repayment incomes).
  Future<void> linkTransactions(String aId, String bId) =>
      dao.linkTransactions(aId, bId);

  Future<void> unlinkTransactionPair(String aId, String bId) =>
      dao.unlinkTransactionPair(aId, bId);

  Stream<List<TransactionWithLegs>> watchLinkedTransactions(String txId) =>
      dao.watchLinkedTransactions(txId);
}
