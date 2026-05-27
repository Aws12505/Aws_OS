// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gym_dao.dart';

// ignore_for_file: type=lint
mixin _$GymDaoMixin on DatabaseAccessor<AppDatabase> {
  $MeasurementTypesTable get measurementTypes =>
      attachedDatabase.measurementTypes;
  $MeasurementEntriesTable get measurementEntries =>
      attachedDatabase.measurementEntries;
  $MeasurementValuesTable get measurementValues =>
      attachedDatabase.measurementValues;
  $ProgramsTable get programs => attachedDatabase.programs;
  $ProgramDaysTable get programDays => attachedDatabase.programDays;
  $SupersetGroupsTable get supersetGroups => attachedDatabase.supersetGroups;
  $DayExercisesTable get dayExercises => attachedDatabase.dayExercises;
  $ExerciseSetPrescriptionsTable get exerciseSetPrescriptions =>
      attachedDatabase.exerciseSetPrescriptions;
  $DaySessionsTable get daySessions => attachedDatabase.daySessions;
  GymDaoManager get managers => GymDaoManager(this);
}

class GymDaoManager {
  final _$GymDaoMixin _db;
  GymDaoManager(this._db);
  $$MeasurementTypesTableTableManager get measurementTypes =>
      $$MeasurementTypesTableTableManager(
        _db.attachedDatabase,
        _db.measurementTypes,
      );
  $$MeasurementEntriesTableTableManager get measurementEntries =>
      $$MeasurementEntriesTableTableManager(
        _db.attachedDatabase,
        _db.measurementEntries,
      );
  $$MeasurementValuesTableTableManager get measurementValues =>
      $$MeasurementValuesTableTableManager(
        _db.attachedDatabase,
        _db.measurementValues,
      );
  $$ProgramsTableTableManager get programs =>
      $$ProgramsTableTableManager(_db.attachedDatabase, _db.programs);
  $$ProgramDaysTableTableManager get programDays =>
      $$ProgramDaysTableTableManager(_db.attachedDatabase, _db.programDays);
  $$SupersetGroupsTableTableManager get supersetGroups =>
      $$SupersetGroupsTableTableManager(
        _db.attachedDatabase,
        _db.supersetGroups,
      );
  $$DayExercisesTableTableManager get dayExercises =>
      $$DayExercisesTableTableManager(_db.attachedDatabase, _db.dayExercises);
  $$ExerciseSetPrescriptionsTableTableManager get exerciseSetPrescriptions =>
      $$ExerciseSetPrescriptionsTableTableManager(
        _db.attachedDatabase,
        _db.exerciseSetPrescriptions,
      );
  $$DaySessionsTableTableManager get daySessions =>
      $$DaySessionsTableTableManager(_db.attachedDatabase, _db.daySessions);
}
