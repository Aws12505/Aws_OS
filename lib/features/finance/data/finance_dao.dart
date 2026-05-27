import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/tables/finance_tables.dart';

part 'finance_dao.g.dart';

@DriftAccessor(tables: [
  Currencies,
  Accounts,
  Categories,
  CategoryTypes,
  Transactions,
  TransactionLegs,
  ExchangeRates,
  Recurrences,
  ScheduledOccurrences,
])
class FinanceDao extends DatabaseAccessor<AppDatabase> with _$FinanceDaoMixin {
  FinanceDao(super.db);

  // -- Currencies ----------------------------------------------------------

  Stream<List<Currency>> watchCurrencies() {
    return (select(currencies)
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.code),
          ]))
        .watch();
  }

  Future<List<Currency>> getCurrencies() => select(currencies).get();

  Future<Currency?> getCurrency(String id) => (select(currencies)
        ..where((t) => t.id.equals(id)))
      .getSingleOrNull();

  Future<void> upsertCurrency(CurrenciesCompanion c) {
    final now = DateTime.now();
    return into(currencies).insertOnConflictUpdate(
      c.copyWith(updatedAt: Value(now)),
    );
  }

  Future<void> deleteCurrency(String id) =>
      (delete(currencies)..where((t) => t.id.equals(id))).go();

  // -- Accounts ------------------------------------------------------------

  Stream<List<Account>> watchAccounts({bool includeArchived = false}) {
    final q = select(accounts);
    if (!includeArchived) {
      q.where((t) => t.archived.equals(false));
    }
    q.orderBy([
      (t) => OrderingTerm.asc(t.sortOrder),
      (t) => OrderingTerm.asc(t.name),
    ]);
    return q.watch();
  }

  Future<List<Account>> getAccounts() => select(accounts).get();

  Future<Account?> getAccount(String id) =>
      (select(accounts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertAccount(AccountsCompanion a) {
    final now = DateTime.now();
    return into(accounts).insertOnConflictUpdate(
      a.copyWith(updatedAt: Value(now)),
    );
  }

  Future<void> deleteAccount(String id) =>
      (delete(accounts)..where((t) => t.id.equals(id))).go();

  // -- Categories & Types --------------------------------------------------

  Stream<List<Category>> watchCategoriesByKind(String kind) {
    return (select(categories)
          ..where((t) => t.kind.equals(kind))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .watch();
  }

  Stream<List<Category>> watchCategories() {
    return (select(categories)
          ..orderBy([
            (t) => OrderingTerm.asc(t.kind),
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .watch();
  }

  Future<void> upsertCategory(CategoriesCompanion c) {
    final now = DateTime.now();
    return into(categories)
        .insertOnConflictUpdate(c.copyWith(updatedAt: Value(now)));
  }

  Future<void> deleteCategory(String id) =>
      (delete(categories)..where((t) => t.id.equals(id))).go();

  Stream<List<CategoryType>> watchTypesForCategory(String categoryId) {
    return (select(categoryTypes)
          ..where((t) => t.categoryId.equals(categoryId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .watch();
  }

  Stream<List<CategoryType>> watchAllTypes() {
    return (select(categoryTypes)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<void> upsertType(CategoryTypesCompanion t) {
    final now = DateTime.now();
    return into(categoryTypes)
        .insertOnConflictUpdate(t.copyWith(updatedAt: Value(now)));
  }

  Future<void> deleteType(String id) =>
      (delete(categoryTypes)..where((t) => t.id.equals(id))).go();

  // -- Recurrences ---------------------------------------------------------

  Stream<List<Recurrence>> watchRecurrences() {
    return (select(recurrences)
          ..orderBy([
            (t) => OrderingTerm.asc(t.endedAt),
            (t) => OrderingTerm.asc(t.nextDueAt),
          ]))
        .watch();
  }

  Future<Recurrence?> getRecurrence(String id) =>
      (select(recurrences)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Recurrence> upsertRecurrenceReturning(RecurrencesCompanion r) async {
    final now = DateTime.now();
    return into(recurrences)
        .insertReturning(r.copyWith(updatedAt: Value(now)),
            mode: InsertMode.insertOrReplace);
  }

  Future<void> updateRecurrenceNextDue(String id, DateTime? nextDueAt) {
    return (update(recurrences)..where((t) => t.id.equals(id))).write(
      RecurrencesCompanion(
        nextDueAt: Value(nextDueAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteRecurrence(String id) =>
      (delete(recurrences)..where((t) => t.id.equals(id))).go();

  // -- Scheduled occurrences -----------------------------------------------

  Stream<List<ScheduledOccurrence>> watchPendingOccurrencesUpTo(DateTime end) {
    return (select(scheduledOccurrences)
          ..where((t) =>
              t.status.equals('pending') & t.dueAt.isSmallerOrEqualValue(end))
          ..orderBy([(t) => OrderingTerm.asc(t.dueAt)]))
        .watch();
  }

  Stream<List<ScheduledOccurrence>> watchOccurrencesForRecurrence(
      String recurrenceId) {
    return (select(scheduledOccurrences)
          ..where((t) => t.recurrenceId.equals(recurrenceId))
          ..orderBy([(t) => OrderingTerm.asc(t.dueAt)]))
        .watch();
  }

  Future<ScheduledOccurrence?> getOccurrence(String id) =>
      (select(scheduledOccurrences)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<List<ScheduledOccurrence>> getOccurrencesForRecurrenceInRange(
      String recurrenceId, DateTime from, DateTime to) {
    return (select(scheduledOccurrences)
          ..where((t) =>
              t.recurrenceId.equals(recurrenceId) &
              t.dueAt.isBiggerOrEqualValue(from) &
              t.dueAt.isSmallerOrEqualValue(to)))
        .get();
  }

  Future<void> insertOccurrence(ScheduledOccurrencesCompanion o) {
    return into(scheduledOccurrences).insert(o);
  }

  Future<void> markOccurrenceStatus(
      String id, String status, String? materializedTxId) {
    return (update(scheduledOccurrences)..where((t) => t.id.equals(id))).write(
      ScheduledOccurrencesCompanion(
        status: Value(status),
        materializedTransactionId: Value(materializedTxId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteOccurrencesForRecurrence(String recurrenceId) =>
      (delete(scheduledOccurrences)
            ..where((t) =>
                t.recurrenceId.equals(recurrenceId) &
                t.status.equals('pending')))
          .go();

  // -- Balances ------------------------------------------------------------

  /// Stream of `{accountId: balance}` aggregated from all transaction legs.
  Stream<Map<String, double>> watchAccountBalances() {
    final sumExpr = transactionLegs.amount.sum();
    final query = selectOnly(transactionLegs)
      ..addColumns([transactionLegs.accountId, sumExpr])
      ..groupBy([transactionLegs.accountId]);
    return query.watch().map((rows) {
      final result = <String, double>{};
      for (final row in rows) {
        final id = row.read(transactionLegs.accountId);
        final sum = row.read(sumExpr);
        if (id != null) result[id] = sum ?? 0.0;
      }
      return result;
    });
  }

  // -- Transactions --------------------------------------------------------

  Stream<List<TransactionWithLegs>> watchRecentTransactions({int limit = 100}) {
    final q = select(transactions)
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
      ..limit(limit);
    return q.watch().asyncMap((txs) async {
      if (txs.isEmpty) return const <TransactionWithLegs>[];
      final ids = txs.map((t) => t.id).toList();
      final legs = await (select(transactionLegs)
            ..where((t) => t.transactionId.isIn(ids)))
          .get();
      final byTx = <String, List<TransactionLeg>>{};
      for (final l in legs) {
        byTx.putIfAbsent(l.transactionId, () => []).add(l);
      }
      return [
        for (final tx in txs)
          TransactionWithLegs(tx, byTx[tx.id] ?? const []),
      ];
    });
  }

  Future<TransactionWithLegs?> getTransactionWithLegs(String id) async {
    final tx = await (select(transactions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (tx == null) return null;
    final legs = await (select(transactionLegs)
          ..where((t) => t.transactionId.equals(id)))
        .get();
    return TransactionWithLegs(tx, legs);
  }

  Future<String> insertTransaction({
    required TransactionsCompanion tx,
    required List<TransactionLegsCompanion> legs,
    ExchangeRatesCompanion? rate,
  }) {
    return transaction(() async {
      final now = DateTime.now();
      final inserted = await into(transactions)
          .insertReturning(tx.copyWith(updatedAt: Value(now)));
      final txId = inserted.id;
      for (final leg in legs) {
        await into(transactionLegs).insert(
          leg.copyWith(transactionId: Value(txId), updatedAt: Value(now)),
        );
      }
      if (rate != null) {
        await into(exchangeRates).insert(
          rate.copyWith(transactionId: Value(txId), updatedAt: Value(now)),
        );
      }
      return txId;
    });
  }

  Future<void> deleteTransaction(String id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  // -- Exchange rates ------------------------------------------------------

  Stream<List<ExchangeRate>> watchExchangeRates({int limit = 200}) {
    return (select(exchangeRates)
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
          ..limit(limit))
        .watch();
  }
}

/// Plain pair returned from queries that join a transaction with its legs.
class TransactionWithLegs {
  const TransactionWithLegs(this.transaction, this.legs);
  final Transaction transaction;
  final List<TransactionLeg> legs;
}
