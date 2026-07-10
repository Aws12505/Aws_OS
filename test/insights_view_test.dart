import 'package:aws_os/features/dashboard/data/day_summary.dart';
import 'package:aws_os/features/dashboard/data/insights_service.dart';
import 'package:aws_os/features/dashboard/presentation/insights_providers.dart';
import 'package:aws_os/features/dashboard/presentation/insights_view.dart';
import 'package:aws_os/features/mentor/data/forecast_service.dart';
import 'package:aws_os/features/mentor/presentation/mentor_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('InsightsView builds every chart section without exceptions', (
    tester,
  ) async {
    // Tall surface so the lazy ListView builds every section (incl. the last).
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = DateTime(2026, 6, 25);
    final days = <DaySummary>[
      for (var i = 0; i < 14; i++)
        DaySummary(
          date: DateTime(base.year, base.month, base.day + i),
          tasksDue: i % 3 == 0 ? 2 : 0,
          tasksDone: i % 3 == 0 ? 1 : 0,
          incomeByCurrency: const {},
          expenseByCurrency: const {},
          topExpenseCategories: const [],
          transactionCount: 0,
          workedOut: i % 4 == 0,
          sessionCount: i % 4 == 0 ? 1 : 0,
          notesCount: i % 5 == 0 ? 1 : 0,
        ),
    ];
    final range = RangeSummary(
      start: days.first.date,
      end: days.last.date,
      days: days,
    );

    const prod = ProductivityForecast(
      hasData: true,
      windowDays: 30,
      due: 20,
      done: 15,
      completionRate: 0.75,
      overdue: 2,
      dailyCompletion: [0.5, 1.0, 0.8],
      slopePerDay: 0.1,
    );
    const gym = GymForecast(
      hasData: true,
      totalSessions: 8,
      weeks: 8,
      sessionsPerWeek: 2.0,
      currentWeekStreak: 3,
      lastSessionDaysAgo: 1,
      measurements: [
        MeasurementTrend(
          name: 'Weight',
          unit: 'kg',
          first: 80.0,
          latest: 78.0,
          slopePerWeek: -0.5,
          projected4w: 76.0,
          count: 5,
          series: [80.0, 79.5, 79.0, 78.5, 78.0],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightsRangeSummaryProvider.overrideWith((ref) => AsyncData(range)),
          currencyInsightsProvider.overrideWith(
            (ref) => AsyncData(const <CurrencyInsight>[]),
          ),
          financeForecastsAllProvider.overrideWith(
            (ref) => AsyncData(const <FinanceForecast>[]),
          ),
          budgetVsActualProvider.overrideWith(
            (ref) => AsyncData(const <BudgetActual>[]),
          ),
          productivityForecastProvider.overrideWith(
            (ref) => const AsyncData(prod),
          ),
          gymForecastProvider.overrideWith((ref) => const AsyncData(gym)),
        ],
        child: const MaterialApp(home: Scaffold(body: InsightsView())),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Productivity'), findsOneWidget);
    expect(find.text('Gym & body'), findsOneWidget);
    expect(find.text('Consistency'), findsOneWidget);
  });
}
