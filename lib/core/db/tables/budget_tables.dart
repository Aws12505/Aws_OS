import 'package:drift/drift.dart';

import '_syncable.dart';

/// A spending limit for an expense category. v1 supports monthly limits; the
/// `period` column leaves room for weekly/yearly later. Amounts are in the
/// user's main currency (spend is summed across legs, currency-agnostic, to
/// mirror the dashboard expense breakdown).
class Budgets extends Table with SyncableColumns {
  @override
  String get tableName => 'budgets';

  TextColumn get categoryId => text().customConstraint(
      'NOT NULL REFERENCES categories(id) ON DELETE CASCADE')();
  RealColumn get amount => real()();
  // 'monthly' (room for 'weekly' | 'yearly')
  TextColumn get period => text().withDefault(const Constant('monthly'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {categoryId, period},
      ];
}
