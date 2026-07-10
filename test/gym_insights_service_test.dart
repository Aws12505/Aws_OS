import 'package:aws_os/core/db/app_database.dart';
import 'package:aws_os/features/gym/data/gym_insights_service.dart';
import 'package:aws_os/features/gym/presentation/gym_insights_providers.dart';
import 'package:aws_os/features/gym/presentation/gym_insights_view.dart';
import 'package:aws_os/features/gym/presentation/providers.dart';
import 'package:aws_os/features/mentor/data/forecast_service.dart';
import 'package:aws_os/features/mentor/presentation/mentor_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _base = DateTime(2026, 6, 1); // a Monday

DaySession _sess(String id, DateTime at) => DaySession(
      id: id,
      createdAt: _base,
      updatedAt: _base,
      programDayId: 'd1',
      playedAt: at,
    );

void main() {
  const svc = GymInsightsService();

  group('GymInsightsService.build', () {
    test('daily bucketing counts sessions per day', () {
      final gi = svc.build(
        sessions: [
          _sess('a', DateTime(2026, 6, 1, 9)),
          _sess('b', DateTime(2026, 6, 3, 18)),
          _sess('c', DateTime(2026, 6, 3, 20)),
        ],
        entries: const [],
        values: const [],
        types: const [],
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 7),
        daily: true,
      );
      expect(gi.bars.length, 7);
      expect(gi.bars[0].value, 1); // Jun 1
      expect(gi.bars[2].value, 2); // Jun 3 — two sessions
      expect(gi.totalSessions, 3);
      expect(gi.activeDays, 2);
    });

    test('weekly bucketing groups sessions by week', () {
      final gi = svc.build(
        sessions: [
          _sess('a', DateTime(2026, 6, 2)),
          _sess('b', DateTime(2026, 6, 9)),
          _sess('c', DateTime(2026, 6, 10)),
        ],
        entries: const [],
        values: const [],
        types: const [],
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 14),
        daily: false,
      );
      expect(gi.bars.length, 2);
      expect(gi.bars[0].value, 1); // week of Jun 1
      expect(gi.bars[1].value, 2); // week of Jun 8
    });

    test('out-of-range sessions are excluded', () {
      final gi = svc.build(
        sessions: [
          _sess('in', DateTime(2026, 6, 5)),
          _sess('out', DateTime(2026, 5, 1)),
        ],
        entries: const [],
        values: const [],
        types: const [],
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 30),
        daily: false,
      );
      expect(gi.totalSessions, 1);
      expect(gi.sessions.single.id, 'in');
    });

    test('measurement series built within range, ascending', () {
      final weight = MeasurementType(
        id: 'w',
        createdAt: _base,
        updatedAt: _base,
        name: 'Weight',
        unit: 'kg',
        sortOrder: 0,
      );
      MeasurementEntry entry(String id, DateTime at) => MeasurementEntry(
            id: id,
            createdAt: _base,
            updatedAt: _base,
            takenAt: at,
          );
      MeasurementValue val(String id, String entryId, double v) =>
          MeasurementValue(
            id: id,
            createdAt: _base,
            updatedAt: _base,
            entryId: entryId,
            typeId: 'w',
            value: v,
          );

      final gi = svc.build(
        sessions: const [],
        entries: [
          entry('e1', DateTime(2026, 6, 3)),
          entry('e2', DateTime(2026, 6, 10)),
          entry('e3', DateTime(2026, 5, 1)), // out of range
        ],
        values: [
          val('v1', 'e1', 80),
          val('v2', 'e2', 78),
          val('v3', 'e3', 90),
        ],
        types: [weight],
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 30),
        daily: false,
      );
      expect(gi.measurements.length, 1);
      final m = gi.measurements.single;
      expect(m.points.length, 2); // e3 excluded
      expect(m.first, 80);
      expect(m.latest, 78);
      expect(m.change, -2);
    });
  });

  testWidgets('GymInsightsView builds every section without exceptions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final weight = MeasurementType(
      id: 'w',
      createdAt: _base,
      updatedAt: _base,
      name: 'Weight',
      unit: 'kg',
      sortOrder: 0,
    );
    final gi = GymInsights(
      bars: [
        for (var i = 0; i < 4; i++)
          GymBar(
            start: DateTime(2026, 6, 1 + i * 7),
            label: 'w$i',
            value: (i % 2 + 1).toDouble(),
          ),
      ],
      days: [
        for (var i = 0; i < 28; i++)
          GymDay(date: DateTime(2026, 6, 1 + i), count: i % 3 == 0 ? 1 : 0),
      ],
      measurements: [
        MeasurementSeries(type: weight, points: [
          MeasPoint(date: DateTime(2026, 6, 3), value: 80),
          MeasPoint(date: DateTime(2026, 6, 20), value: 78),
        ]),
      ],
      sessions: [_sess('s1', DateTime(2026, 6, 20, 18))],
      totalSessions: 5,
      activeDays: 5,
      sessionsPerWeek: 1.4,
    );
    const forecast = GymForecast(
      hasData: true,
      totalSessions: 5,
      weeks: 8,
      sessionsPerWeek: 1.4,
      currentWeekStreak: 2,
      lastSessionDaysAgo: 1,
      measurements: [],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        gymInsightsProvider.overrideWith((ref) => AsyncData(gi)),
        gymForecastProvider.overrideWith((ref) => const AsyncData(forecast)),
        allProgramDaysProvider
            .overrideWith((ref) => Stream.value(const <ProgramDay>[])),
        programsStreamProvider
            .overrideWith((ref) => Stream.value(const <Program>[])),
        allDayExercisesProvider
            .overrideWith((ref) => Stream.value(const <DayExercise>[])),
        allPrescriptionsProvider.overrideWith(
            (ref) => Stream.value(const <ExerciseSetPrescription>[])),
      ],
      child: const MaterialApp(home: Scaffold(body: GymInsightsView())),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Workouts over time'), findsOneWidget);
    expect(find.text('Consistency'), findsOneWidget);
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('Workout history'), findsOneWidget);
  });
}
