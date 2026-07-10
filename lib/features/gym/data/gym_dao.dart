import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/tables/gym_tables.dart';

part 'gym_dao.g.dart';

@DriftAccessor(
  tables: [
    MeasurementTypes,
    MeasurementEntries,
    MeasurementValues,
    Programs,
    ProgramDays,
    SupersetGroups,
    DayExercises,
    ExerciseSetPrescriptions,
    DaySessions,
  ],
)
class GymDao extends DatabaseAccessor<AppDatabase> with _$GymDaoMixin {
  GymDao(super.db);

  // -- Measurement types ---------------------------------------------------

  Stream<List<MeasurementType>> watchMeasurementTypes() {
    return (select(measurementTypes)..orderBy([
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.asc(t.name),
        ]))
        .watch();
  }

  Future<void> upsertMeasurementType(MeasurementTypesCompanion c) {
    final now = DateTime.now();
    return into(
      measurementTypes,
    ).insertOnConflictUpdate(c.copyWith(updatedAt: Value(now)));
  }

  Future<void> deleteMeasurementType(String id) =>
      (delete(measurementTypes)..where((t) => t.id.equals(id))).go();

  // -- Measurement entries -------------------------------------------------

  Stream<List<MeasurementEntry>> watchEntries() {
    return (select(
      measurementEntries,
    )..orderBy([(t) => OrderingTerm.desc(t.takenAt)])).watch();
  }

  Stream<List<MeasurementValue>> watchValues() {
    return select(measurementValues).watch();
  }

  Future<MeasurementEntry> insertEntryReturning({
    required DateTime takenAt,
    String? note,
    required Map<String, double> values, // typeId -> value
  }) async {
    return transaction(() async {
      final entry = await into(measurementEntries).insertReturning(
        MeasurementEntriesCompanion(takenAt: Value(takenAt), note: Value(note)),
      );
      for (final e in values.entries) {
        await into(measurementValues).insert(
          MeasurementValuesCompanion(
            entryId: Value(entry.id),
            typeId: Value(e.key),
            value: Value(e.value),
          ),
        );
      }
      return entry;
    });
  }

  Future<void> deleteEntry(String id) =>
      (delete(measurementEntries)..where((t) => t.id.equals(id))).go();

  // -- Programs ------------------------------------------------------------

  Stream<List<Program>> watchPrograms() {
    return (select(programs)..orderBy([
          (t) => OrderingTerm.asc(t.endedAt),
          (t) => OrderingTerm.desc(t.startedAt),
        ]))
        .watch();
  }

  Future<Program> upsertProgramReturning(ProgramsCompanion p) async {
    final now = DateTime.now();
    return into(programs).insertReturning(
      p.copyWith(updatedAt: Value(now)),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> deleteProgram(String id) =>
      (delete(programs)..where((t) => t.id.equals(id))).go();

  // -- Days ---------------------------------------------------------------

  Stream<List<ProgramDay>> watchDaysForProgram(String programId) {
    return (select(programDays)
          ..where((t) => t.programId.equals(programId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .watch();
  }

  /// Every program day across all programs — lets the workout-history list
  /// resolve a session's `programDayId` back to its day (and program) name.
  Stream<List<ProgramDay>> watchAllDays() {
    return (select(
      programDays,
    )..orderBy([(t) => OrderingTerm.asc(t.position)])).watch();
  }

  Future<ProgramDay> upsertDayReturning(ProgramDaysCompanion d) async {
    final now = DateTime.now();
    return into(programDays).insertReturning(
      d.copyWith(updatedAt: Value(now)),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> deleteDay(String id) =>
      (delete(programDays)..where((t) => t.id.equals(id))).go();

  // -- Exercises ----------------------------------------------------------

  Stream<List<DayExercise>> watchExercisesForDay(String dayId) {
    return (select(dayExercises)
          ..where((t) => t.dayId.equals(dayId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .watch();
  }

  /// Every exercise across all program days — lets progression charts merge a
  /// movement (by name) across the different days it appears in.
  Stream<List<DayExercise>> watchAllExercises() {
    return select(dayExercises).watch();
  }

  Stream<List<SupersetGroup>> watchSupersetsForDay(String dayId) {
    return (select(supersetGroups)
          ..where((t) => t.dayId.equals(dayId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .watch();
  }

  Future<DayExercise> upsertExerciseReturning(DayExercisesCompanion e) async {
    final now = DateTime.now();
    return into(dayExercises).insertReturning(
      e.copyWith(updatedAt: Value(now)),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<SupersetGroup> insertSupersetReturning({
    required String dayId,
    required int position,
    int targetSets = 1,
  }) {
    return into(supersetGroups).insertReturning(
      SupersetGroupsCompanion(
        dayId: Value(dayId),
        position: Value(position),
        targetSets: Value(targetSets),
      ),
    );
  }

  Future<void> updateSuperset(String id, {int? targetSets}) {
    return (update(supersetGroups)..where((t) => t.id.equals(id))).write(
      SupersetGroupsCompanion(
        targetSets: targetSets == null
            ? const Value.absent()
            : Value(targetSets),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteExercise(String id) =>
      (delete(dayExercises)..where((t) => t.id.equals(id))).go();

  Future<void> deleteSuperset(String id) =>
      (delete(supersetGroups)..where((t) => t.id.equals(id))).go();

  // -- Prescriptions ------------------------------------------------------

  Stream<List<ExerciseSetPrescription>> watchPrescriptionsForExercise(
    String dayExerciseId,
  ) {
    return (select(exerciseSetPrescriptions)
          ..where((t) => t.dayExerciseId.equals(dayExerciseId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.setIndex),
            (t) => OrderingTerm.desc(t.effectiveFrom),
          ]))
        .watch();
  }

  /// Every prescription row across all exercises — the append-only, timestamped
  /// history that powers progression (each edit of a set is one row).
  Stream<List<ExerciseSetPrescription>> watchAllPrescriptions() {
    return select(exerciseSetPrescriptions).watch();
  }

  Future<void> insertPrescription({
    required String dayExerciseId,
    required int setIndex,
    required int reps,
    required double weight,
  }) {
    return into(exerciseSetPrescriptions).insert(
      ExerciseSetPrescriptionsCompanion(
        dayExerciseId: Value(dayExerciseId),
        setIndex: Value(setIndex),
        reps: Value(reps),
        weight: Value(weight),
        effectiveFrom: Value(DateTime.now()),
      ),
    );
  }

  // -- Day sessions -------------------------------------------------------

  Stream<List<DaySession>> watchSessionsForDay(String dayId) {
    return (select(daySessions)
          ..where((t) => t.programDayId.equals(dayId))
          ..orderBy([(t) => OrderingTerm.desc(t.playedAt)]))
        .watch();
  }

  Stream<List<DaySession>> watchAllSessions() {
    return (select(
      daySessions,
    )..orderBy([(t) => OrderingTerm.desc(t.playedAt)])).watch();
  }

  Future<void> insertSession({
    required String dayId,
    required DateTime playedAt,
    String? note,
  }) {
    return into(daySessions).insert(
      DaySessionsCompanion(
        programDayId: Value(dayId),
        playedAt: Value(playedAt),
        note: Value(note),
      ),
    );
  }

  Future<void> deleteSession(String id) =>
      (delete(daySessions)..where((t) => t.id.equals(id))).go();
}
