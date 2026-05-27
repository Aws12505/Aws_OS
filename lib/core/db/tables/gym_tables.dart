import 'package:drift/drift.dart';

import '_syncable.dart';

class MeasurementTypes extends Table with SyncableColumns {
  @override
  String get tableName => 'measurement_types';

  TextColumn get name => text()();
  TextColumn get unit => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class MeasurementEntries extends Table with SyncableColumns {
  @override
  String get tableName => 'measurement_entries';

  DateTimeColumn get takenAt => dateTime()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class MeasurementValues extends Table with SyncableColumns {
  @override
  String get tableName => 'measurement_values';

  TextColumn get entryId => text().customConstraint(
      'NOT NULL REFERENCES measurement_entries(id) ON DELETE CASCADE')();
  TextColumn get typeId =>
      text().customConstraint('NOT NULL REFERENCES measurement_types(id)')();
  RealColumn get value => real()();

  @override
  Set<Column> get primaryKey => {id};
}

class Programs extends Table with SyncableColumns {
  @override
  String get tableName => 'programs';

  TextColumn get name => text()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ProgramDays extends Table with SyncableColumns {
  @override
  String get tableName => 'program_days';

  TextColumn get programId => text().customConstraint(
      'NOT NULL REFERENCES programs(id) ON DELETE CASCADE')();
  TextColumn get name => text()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class SupersetGroups extends Table with SyncableColumns {
  @override
  String get tableName => 'superset_groups';

  TextColumn get dayId => text().customConstraint(
      'NOT NULL REFERENCES program_days(id) ON DELETE CASCADE')();
  IntColumn get position => integer()();
  IntColumn get targetSets => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

class DayExercises extends Table with SyncableColumns {
  @override
  String get tableName => 'day_exercises';

  TextColumn get dayId => text().customConstraint(
      'NOT NULL REFERENCES program_days(id) ON DELETE CASCADE')();
  TextColumn get supersetGroupId => text().nullable().customConstraint(
      'NULL REFERENCES superset_groups(id) ON DELETE CASCADE')();
  IntColumn get position => integer()();
  TextColumn get exerciseName => text()();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();

  @override
  Set<Column> get primaryKey => {id};
}

class ExerciseSetPrescriptions extends Table with SyncableColumns {
  @override
  String get tableName => 'exercise_set_prescriptions';

  TextColumn get dayExerciseId => text().customConstraint(
      'NOT NULL REFERENCES day_exercises(id) ON DELETE CASCADE')();
  IntColumn get setIndex => integer()();
  IntColumn get reps => integer()();
  RealColumn get weight => real()();
  DateTimeColumn get effectiveFrom =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

class DaySessions extends Table with SyncableColumns {
  @override
  String get tableName => 'day_sessions';

  TextColumn get programDayId => text().customConstraint(
      'NOT NULL REFERENCES program_days(id) ON DELETE CASCADE')();
  DateTimeColumn get playedAt => dateTime()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
