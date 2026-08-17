import 'package:drift/drift.dart';

import '_syncable.dart';

class Currencies extends Table with SyncableColumns {
  @override
  String get tableName => 'currencies';

  TextColumn get code => text().withLength(min: 1, max: 10)();
  TextColumn get symbol => text().withLength(min: 1, max: 10)();
  IntColumn get decimalPlaces => integer().withDefault(const Constant(2))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Accounts extends Table with SyncableColumns {
  @override
  String get tableName => 'accounts';

  TextColumn get name => text()();
  TextColumn get currencyId =>
      text().customConstraint('NOT NULL REFERENCES currencies(id)')();
  TextColumn get kind => text().withDefault(const Constant('cash'))();
  IntColumn get color => integer().nullable()();
  TextColumn get icon => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table with SyncableColumns {
  @override
  String get tableName => 'categories';

  TextColumn get name => text()();
  // 'income' | 'expense'
  TextColumn get kind => text()();
  IntColumn get color => integer().nullable()();
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class CategoryTypes extends Table with SyncableColumns {
  @override
  String get tableName => 'category_types';

  TextColumn get categoryId =>
      text().customConstraint('NOT NULL REFERENCES categories(id)')();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table with SyncableColumns {
  @override
  String get tableName => 'transactions';

  // 'income' | 'expense' | 'exchange' | 'transfer'
  TextColumn get kind => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get categoryId => text()
      .nullable()
      .customConstraint('NULL REFERENCES categories(id)')();
  TextColumn get typeId => text()
      .nullable()
      .customConstraint('NULL REFERENCES category_types(id)')();
  TextColumn get recurrenceId => text().nullable()();
  TextColumn get scheduledOccurrenceId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class TransactionLegs extends Table with SyncableColumns {
  @override
  String get tableName => 'transaction_legs';

  TextColumn get transactionId => text().customConstraint(
      'NOT NULL REFERENCES transactions(id) ON DELETE CASCADE')();
  TextColumn get accountId =>
      text().customConstraint('NOT NULL REFERENCES accounts(id)')();
  TextColumn get currencyId =>
      text().customConstraint('NOT NULL REFERENCES currencies(id)')();
  // Signed: positive = inflow into account, negative = outflow.
  RealColumn get amount => real()();

  @override
  Set<Column> get primaryKey => {id};
}

class TransactionLinks extends Table with SyncableColumns {
  @override
  String get tableName => 'transaction_links';

  // Undirected link between two transactions of any kind. Query by either
  // column to find everything linked to a given transaction.
  TextColumn get transactionId => text().customConstraint(
      'NOT NULL REFERENCES transactions(id) ON DELETE CASCADE')();
  TextColumn get linkedTransactionId => text().customConstraint(
      'NOT NULL REFERENCES transactions(id) ON DELETE CASCADE')();

  @override
  Set<Column> get primaryKey => {id};
}

class ExchangeRates extends Table with SyncableColumns {
  @override
  String get tableName => 'exchange_rates';

  TextColumn get fromCurrencyId =>
      text().customConstraint('NOT NULL REFERENCES currencies(id)')();
  TextColumn get toCurrencyId =>
      text().customConstraint('NOT NULL REFERENCES currencies(id)')();
  // `to_amount = from_amount * rate`.
  RealColumn get rate => real()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get transactionId => text().nullable().customConstraint(
      'NULL REFERENCES transactions(id) ON DELETE SET NULL')();

  @override
  Set<Column> get primaryKey => {id};
}

class Recurrences extends Table with SyncableColumns {
  @override
  String get tableName => 'recurrences';

  // 'income' | 'expense'
  TextColumn get kind => text()();
  TextColumn get ruleJson => text()();
  TextColumn get templateLegsJson => text()();
  TextColumn get categoryId => text()
      .nullable()
      .customConstraint('NULL REFERENCES categories(id)')();
  TextColumn get typeId => text()
      .nullable()
      .customConstraint('NULL REFERENCES category_types(id)')();
  TextColumn get noteTemplate => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get nextDueAt => dateTime().nullable()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ScheduledOccurrences extends Table with SyncableColumns {
  @override
  String get tableName => 'scheduled_occurrences';

  TextColumn get recurrenceId => text().customConstraint(
      'NOT NULL REFERENCES recurrences(id) ON DELETE CASCADE')();
  DateTimeColumn get dueAt => dateTime()();
  // 'pending' | 'confirmed' | 'skipped'
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get materializedTransactionId => text().nullable().customConstraint(
      'NULL REFERENCES transactions(id) ON DELETE SET NULL')();
  DateTimeColumn get lastReminderAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
