import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../data/gym_dao.dart';

final gymDaoProvider = Provider<GymDao>((ref) {
  return GymDao(ref.watch(databaseProvider));
});

final measurementTypesStreamProvider =
    StreamProvider<List<MeasurementType>>((ref) {
  return ref.watch(gymDaoProvider).watchMeasurementTypes();
});

final measurementEntriesStreamProvider =
    StreamProvider<List<MeasurementEntry>>((ref) {
  return ref.watch(gymDaoProvider).watchEntries();
});

final measurementValuesStreamProvider =
    StreamProvider<List<MeasurementValue>>((ref) {
  return ref.watch(gymDaoProvider).watchValues();
});

final programsStreamProvider = StreamProvider<List<Program>>((ref) {
  return ref.watch(gymDaoProvider).watchPrograms();
});

final daysForProgramProvider =
    StreamProvider.family<List<ProgramDay>, String>((ref, programId) {
  return ref.watch(gymDaoProvider).watchDaysForProgram(programId);
});

final exercisesForDayProvider =
    StreamProvider.family<List<DayExercise>, String>((ref, dayId) {
  return ref.watch(gymDaoProvider).watchExercisesForDay(dayId);
});

final supersetsForDayProvider =
    StreamProvider.family<List<SupersetGroup>, String>((ref, dayId) {
  return ref.watch(gymDaoProvider).watchSupersetsForDay(dayId);
});

final prescriptionsForExerciseProvider =
    StreamProvider.family<List<ExerciseSetPrescription>, String>(
        (ref, exerciseId) {
  return ref.watch(gymDaoProvider).watchPrescriptionsForExercise(exerciseId);
});

final sessionsForDayProvider =
    StreamProvider.family<List<DaySession>, String>((ref, dayId) {
  return ref.watch(gymDaoProvider).watchSessionsForDay(dayId);
});

final allSessionsStreamProvider = StreamProvider<List<DaySession>>((ref) {
  return ref.watch(gymDaoProvider).watchAllSessions();
});
