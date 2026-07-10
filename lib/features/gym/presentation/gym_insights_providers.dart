import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../shared/utils/insights_range.dart';
import '../data/gym_insights_service.dart';
import '../data/gym_progression_service.dart';
import 'providers.dart';

/// Selected time window for the gym Insights tab.
final gymRangeProvider = StateProvider<InsightsRange>((_) => InsightsRange.d30);

final gymInsightsServiceProvider = Provider<GymInsightsService>(
  (_) => const GymInsightsService(),
);

/// Range-scoped gym analytics, composed from the session + measurement streams.
final gymInsightsProvider = Provider<AsyncValue<GymInsights>>((ref) {
  final range = ref.watch(gymRangeProvider);
  final (start, end) = range.window(DateTime.now());
  final daily = range == InsightsRange.d7;

  final sessionsA = ref.watch(allSessionsStreamProvider);
  final entriesA = ref.watch(measurementEntriesStreamProvider);
  final valuesA = ref.watch(measurementValuesStreamProvider);
  final typesA = ref.watch(measurementTypesStreamProvider);

  final xs = <AsyncValue<Object?>>[sessionsA, entriesA, valuesA, typesA];
  for (final a in xs) {
    if (a.isLoading && !a.hasValue) return const AsyncValue.loading();
  }
  for (final a in xs) {
    if (a.hasError) {
      return AsyncValue.error(a.error!, a.stackTrace ?? StackTrace.current);
    }
  }

  final svc = ref.watch(gymInsightsServiceProvider);
  return AsyncValue.data(
    svc.build(
      sessions: sessionsA.value ?? const <DaySession>[],
      entries: entriesA.value ?? const <MeasurementEntry>[],
      values: valuesA.value ?? const <MeasurementValue>[],
      types: typesA.value ?? const <MeasurementType>[],
      start: start,
      end: end,
      daily: daily,
    ),
  );
});

// ── progression (all-time, derived from the prescription-edit history) ───────

final gymProgressionServiceProvider = Provider<GymProgressionService>(
  (_) => const GymProgressionService(),
);

/// Movement names that have logged prescription history — the picker options.
final progressionExerciseNamesProvider = Provider<List<String>>((ref) {
  final exercises =
      ref.watch(allDayExercisesProvider).value ?? const <DayExercise>[];
  final prescriptions =
      ref.watch(allPrescriptionsProvider).value ??
      const <ExerciseSetPrescription>[];
  return ref
      .watch(gymProgressionServiceProvider)
      .exerciseNames(exercises, prescriptions);
});

/// Selected movement for the progression chart (null → first available).
final selectedProgressionExerciseProvider = StateProvider<String?>((_) => null);

final exerciseProgressionProvider = Provider<ExerciseProgression?>((ref) {
  final names = ref.watch(progressionExerciseNamesProvider);
  if (names.isEmpty) return null;
  final selected = ref.watch(selectedProgressionExerciseProvider);
  final name = (selected != null && names.contains(selected))
      ? selected
      : names.first;
  final exercises =
      ref.watch(allDayExercisesProvider).value ?? const <DayExercise>[];
  final prescriptions =
      ref.watch(allPrescriptionsProvider).value ??
      const <ExerciseSetPrescription>[];
  return ref
      .watch(gymProgressionServiceProvider)
      .build(name: name, exercises: exercises, prescriptions: prescriptions);
});
