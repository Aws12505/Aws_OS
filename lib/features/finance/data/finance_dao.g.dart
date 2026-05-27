// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finance_dao.dart';

// ignore_for_file: type=lint
mixin _$FinanceDaoMixin on DatabaseAccessor<AppDatabase> {
  $CurrenciesTable get currencies => attachedDatabase.currencies;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $CategoriesTable get categories => attachedDatabase.categories;
  $CategoryTypesTable get categoryTypes => attachedDatabase.categoryTypes;
  $TransactionsTable get transactions => attachedDatabase.transactions;
  $TransactionLegsTable get transactionLegs => attachedDatabase.transactionLegs;
  $ExchangeRatesTable get exchangeRates => attachedDatabase.exchangeRates;
  $RecurrencesTable get recurrences => attachedDatabase.recurrences;
  $ScheduledOccurrencesTable get scheduledOccurrences =>
      attachedDatabase.scheduledOccurrences;
  FinanceDaoManager get managers => FinanceDaoManager(this);
}

class FinanceDaoManager {
  final _$FinanceDaoMixin _db;
  FinanceDaoManager(this._db);
  $$CurrenciesTableTableManager get currencies =>
      $$CurrenciesTableTableManager(_db.attachedDatabase, _db.currencies);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$CategoryTypesTableTableManager get categoryTypes =>
      $$CategoryTypesTableTableManager(_db.attachedDatabase, _db.categoryTypes);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
  $$TransactionLegsTableTableManager get transactionLegs =>
      $$TransactionLegsTableTableManager(
        _db.attachedDatabase,
        _db.transactionLegs,
      );
  $$ExchangeRatesTableTableManager get exchangeRates =>
      $$ExchangeRatesTableTableManager(_db.attachedDatabase, _db.exchangeRates);
  $$RecurrencesTableTableManager get recurrences =>
      $$RecurrencesTableTableManager(_db.attachedDatabase, _db.recurrences);
  $$ScheduledOccurrencesTableTableManager get scheduledOccurrences =>
      $$ScheduledOccurrencesTableTableManager(
        _db.attachedDatabase,
        _db.scheduledOccurrences,
      );
}
