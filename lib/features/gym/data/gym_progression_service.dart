import 'dart:math' as math;

import '../../../core/db/app_database.dart';

/// One day on which a movement's prescription changed — the top set recorded
/// that day and its Epley estimated 1RM.
class ProgressionPoint {
  const ProgressionPoint({
    required this.date,
    required this.topWeight,
    required this.est1RM,
  });

  final DateTime date;
  final double topWeight;
  final double est1RM;
}

/// All-time progression for one movement (merged across every program day it
/// appears in), ascending by date.
class ExerciseProgression {
  const ExerciseProgression({required this.name, required this.points});

  final String name;
  final List<ProgressionPoint> points;

  bool get hasPoints => points.isNotEmpty;
  bool get hasTrend => points.length >= 2;

  double get latestWeight => points.isEmpty ? 0 : points.last.topWeight;
  double get latest1RM => points.isEmpty ? 0 : points.last.est1RM;
  double get bestWeight =>
      points.isEmpty ? 0 : points.map((p) => p.topWeight).reduce(math.max);
  double get weightChange =>
      points.length < 2 ? 0 : points.last.topWeight - points.first.topWeight;

  List<String> get isoDays => [
    for (final p in points) '${p.date.month}/${p.date.day}',
  ];
}

/// Epley estimated one-rep max.
double estimatedOneRepMax(double weight, int reps) =>
    weight * (1 + reps / 30.0);

/// Pure transforms over the append-only prescription history into per-movement
/// progression series. No schema/logging change — it reads what set edits
/// already record via `effectiveFrom`.
class GymProgressionService {
  const GymProgressionService();

  /// Distinct exercise names that have at least one logged prescription,
  /// case-insensitively sorted for a stable picker.
  List<String> exerciseNames(
    List<DayExercise> exercises,
    List<ExerciseSetPrescription> prescriptions,
  ) {
    final withHistory = {for (final p in prescriptions) p.dayExerciseId};
    final names = <String>{};
    for (final e in exercises) {
      final n = e.exerciseName.trim();
      if (n.isNotEmpty && withHistory.contains(e.id)) names.add(n);
    }
    return names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Build the daily-max progression for one movement name, merging every
  /// program-day instance of it. Each day keeps the heaviest set and best
  /// estimated 1RM recorded that day.
  ExerciseProgression build({
    required String name,
    required List<DayExercise> exercises,
    required List<ExerciseSetPrescription> prescriptions,
  }) {
    final target = name.trim().toLowerCase();
    final ids = {
      for (final e in exercises)
        if (e.exerciseName.trim().toLowerCase() == target) e.id,
    };

    final byDay = <DateTime, ({double w, double orm})>{};
    for (final p in prescriptions) {
      if (!ids.contains(p.dayExerciseId)) continue;
      final d = DateTime(
        p.effectiveFrom.year,
        p.effectiveFrom.month,
        p.effectiveFrom.day,
      );
      final orm = estimatedOneRepMax(p.weight, p.reps);
      final cur = byDay[d];
      byDay[d] = cur == null
          ? (w: p.weight, orm: orm)
          : (w: math.max(cur.w, p.weight), orm: math.max(cur.orm, orm));
    }

    final days = byDay.keys.toList()..sort();
    return ExerciseProgression(
      name: name,
      points: [
        for (final d in days)
          ProgressionPoint(
            date: d,
            topWeight: byDay[d]!.w,
            est1RM: byDay[d]!.orm,
          ),
      ],
    );
  }
}
