import 'package:aws_os/core/db/app_database.dart';
import 'package:aws_os/features/gym/data/gym_insights_service.dart';
import 'package:aws_os/features/gym/data/gym_progression_service.dart';
import 'package:aws_os/features/gym/presentation/gym_insights_providers.dart';
import 'package:aws_os/features/gym/presentation/gym_insights_view.dart';
import 'package:aws_os/features/gym/presentation/providers.dart';
import 'package:aws_os/features/mentor/data/forecast_service.dart';
import 'package:aws_os/features/mentor/presentation/mentor_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _base = DateTime(2026, 6, 1);

DayExercise _ex(String id, String name, {String day = 'd1'}) => DayExercise(
      id: id,
      createdAt: _base,
      updatedAt: _base,
      dayId: day,
      position: 0,
      exerciseName: name,
      targetSets: 3,
    );

ExerciseSetPrescription _pres(
  String id,
  String exId,
  int setIndex,
  int reps,
  double weight,
  DateTime at,
) =>
    ExerciseSetPrescription(
      id: id,
      createdAt: _base,
      updatedAt: _base,
      dayExerciseId: exId,
      setIndex: setIndex,
      reps: reps,
      weight: weight,
      effectiveFrom: at,
    );

void main() {
  const svc = GymProgressionService();

  group('GymProgressionService', () {
    test('exerciseNames lists only movements with history, sorted', () {
      final names = svc.exerciseNames(
        [_ex('e1', 'Squat'), _ex('e2', 'Bench'), _ex('e3', 'Deadlift')],
        [
          _pres('p1', 'e1', 1, 5, 100, _base),
          _pres('p2', 'e2', 1, 5, 80, _base),
        ],
      );
      expect(names, ['Bench', 'Squat']); // Deadlift has no logged history
    });

    test('build merges instances, taking daily max weight and est-1RM', () {
      final exercises = [
        _ex('e1', 'Bench', day: 'd1'),
        _ex('e2', 'Bench', day: 'd2'), // same movement, different program day
      ];
      final d1 = DateTime(2026, 6, 1);
      final d2 = DateTime(2026, 6, 8);
      final prescriptions = [
        _pres('p1', 'e1', 1, 5, 80, d1),
        _pres('p2', 'e1', 2, 5, 60, d1), // lighter set same day
        _pres('p3', 'e2', 1, 3, 82.5, d2),
        _pres('p4', 'e1', 1, 5, 85, d2), // heaviest on day 2
      ];
      final prog = svc.build(
        name: 'Bench',
        exercises: exercises,
        prescriptions: prescriptions,
      );

      expect(prog.points.length, 2);
      expect(prog.points[0].topWeight, 80); // day 1 max
      expect(prog.points[1].topWeight, 85); // day 2 max (85 > 82.5)
      expect(prog.points[1].est1RM, closeTo(85 * (1 + 5 / 30), 1e-6));
      expect(prog.latestWeight, 85);
      expect(prog.bestWeight, 85);
      expect(prog.weightChange, 5); // 85 - 80
    });

    test('excludes other movements', () {
      final prog = svc.build(
        name: 'Bench',
        exercises: [_ex('e1', 'Bench'), _ex('e2', 'Squat')],
        prescriptions: [
          _pres('p1', 'e1', 1, 5, 80, _base),
          _pres('p2', 'e2', 1, 5, 100, _base),
        ],
      );
      expect(prog.points.single.topWeight, 80);
    });
  });

  testWidgets('GymInsightsView renders the Progression section from history',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const emptyGi = GymInsights(
      bars: [],
      days: [],
      measurements: [],
      sessions: [],
      totalSessions: 0,
      activeDays: 0,
      sessionsPerWeek: 0,
    );
    const forecast = GymForecast(
      hasData: false,
      totalSessions: 0,
      weeks: 8,
      sessionsPerWeek: 0,
      currentWeekStreak: 0,
      lastSessionDaysAgo: null,
      measurements: [],
    );
    final exercises = [_ex('e1', 'Bench')];
    final prescriptions = [
      _pres('p1', 'e1', 1, 5, 80, DateTime(2026, 6, 1)),
      _pres('p2', 'e1', 1, 5, 85, DateTime(2026, 6, 8)),
    ];

    await tester.pumpWidget(ProviderScope(
      overrides: [
        gymInsightsProvider.overrideWith((ref) => const AsyncData(emptyGi)),
        gymForecastProvider.overrideWith((ref) => const AsyncData(forecast)),
        allProgramDaysProvider
            .overrideWith((ref) => Stream.value(const <ProgramDay>[])),
        programsStreamProvider
            .overrideWith((ref) => Stream.value(const <Program>[])),
        allDayExercisesProvider.overrideWith((ref) => Stream.value(exercises)),
        allPrescriptionsProvider
            .overrideWith((ref) => Stream.value(prescriptions)),
      ],
      child: const MaterialApp(home: Scaffold(body: GymInsightsView())),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Progression'), findsOneWidget);
    expect(find.text('Bench'), findsWidgets); // picker chip
    expect(find.text('Top set'), findsOneWidget);
  });
}
