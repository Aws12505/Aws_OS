import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/_syncable.dart';
import 'tables/app_settings_table.dart';
import 'tables/budget_tables.dart';
import 'tables/debrief_tables.dart';
import 'tables/finance_tables.dart';
import 'tables/gym_tables.dart';
import 'tables/notes_tables.dart';
import 'tables/tasks_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  AppSettingsTable,
  // Finance
  Currencies,
  Accounts,
  Categories,
  CategoryTypes,
  Transactions,
  TransactionLegs,
  ExchangeRates,
  Recurrences,
  ScheduledOccurrences,
  Budgets,
  // Tasks
  Workspaces,
  TaskRecurrences,
  Tasks,
  TaskHistory,
  // Gym
  MeasurementTypes,
  MeasurementEntries,
  MeasurementValues,
  Programs,
  ProgramDays,
  SupersetGroups,
  DayExercises,
  ExerciseSetPrescriptions,
  DaySessions,
  // Notes
  Notes,
  Tags,
  NoteTags,
  // Debrief
  DebriefEntries,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'aws_os'));

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // v2: end-of-day debrief entries.
          if (from < 2) {
            await m.createTable(debriefEntries);
          }
          // v3: per-category budgets.
          if (from < 3) {
            await m.createTable(budgets);
          }
        },
        beforeOpen: (details) async {
          // SQLite foreign keys are off by default.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
