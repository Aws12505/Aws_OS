import 'package:aws_os/features/dashboard/data/day_summary.dart';
import 'package:aws_os/shared/utils/insights_range.dart';
import 'package:aws_os/features/dashboard/data/insights_service.dart';
import 'package:flutter_test/flutter_test.dart';

DaySummary _day(
  DateTime date, {
  Map<String, double> income = const {},
  Map<String, double> expense = const {},
  int tasksDue = 0,
  int tasksDone = 0,
  bool workedOut = false,
  int sessionCount = 0,
  int notesCount = 0,
}) {
  return DaySummary(
    date: date,
    tasksDue: tasksDue,
    tasksDone: tasksDone,
    incomeByCurrency: income,
    expenseByCurrency: expense,
    topExpenseCategories: const [],
    transactionCount: 0,
    workedOut: workedOut,
    sessionCount: sessionCount,
    notesCount: notesCount,
  );
}

void main() {
  const svc = InsightsService();

  group('compactNumber', () {
    test('formats magnitudes and sign', () {
      expect(compactNumber(42), '42');
      expect(compactNumber(42.5), '42.5');
      expect(compactNumber(950), '950');
      expect(compactNumber(1500), '1.5K');
      expect(compactNumber(2500000), '2.5M');
      expect(compactNumber(-1200), '-1.2K');
    });
  });

  group('activeCurrencyIds', () {
    test('orders by total volume, drops zero-volume currencies', () {
      final r = RangeSummary(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 2),
        days: [
          _day(
            DateTime(2026, 1, 1),
            income: {'usd': 100},
            expense: {'eur': 10},
          ),
          _day(DateTime(2026, 1, 2), expense: {'usd': 50, 'eur': 5}),
        ],
      );
      expect(svc.activeCurrencyIds(r), ['usd', 'eur']);
    });
  });

  group('bucketFlow', () {
    test('daily → one point per day for the currency', () {
      final r = RangeSummary(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 3),
        days: [
          _day(DateTime(2026, 1, 1), income: {'usd': 100}),
          _day(DateTime(2026, 1, 2), expense: {'usd': 40}),
          _day(DateTime(2026, 1, 3), income: {'usd': 10}, expense: {'usd': 5}),
        ],
      );
      final pts = svc.bucketFlow(r, InsightsBucket.daily, 'usd');
      expect(pts.length, 3);
      expect(pts[0].income, 100);
      expect(pts[1].expense, 40);
      expect(pts[2].net, 5);
    });

    test('monthly → folds days into month buckets', () {
      final days = <DaySummary>[
        for (var d = 1; d <= 28; d++)
          _day(DateTime(2026, 1, d), income: {'usd': 10}, expense: {'usd': 4}),
        for (var d = 1; d <= 28; d++)
          _day(DateTime(2026, 2, d), income: {'usd': 20}),
      ];
      final r = RangeSummary(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 2, 28),
        days: days,
      );
      final pts = svc.bucketFlow(r, InsightsBucket.monthly, 'usd');
      expect(pts.length, 2);
      expect(pts[0].income, 280); // 28 * 10
      expect(pts[0].expense, 112); // 28 * 4
      expect(pts[1].income, 560); // 28 * 20
      expect(pts[0].label, 'Jan');
      expect(pts[1].label, 'Feb');
    });
  });

  group('balanceTrend', () {
    test('reconstructs end-of-bucket balances walking current backward', () {
      final pts = [
        FlowPoint(
          start: _epoch,
          label: 'a',
          income: 100,
          expense: 0,
        ), // net +100
        FlowPoint(start: _epoch, label: 'b', income: 0, expense: 30), // net -30
        FlowPoint(
          start: _epoch,
          label: 'c',
          income: 50,
          expense: 20,
        ), // net +30
      ];
      // Current (end of last bucket) = 200.
      final series = svc.balanceTrend(pts, 200);
      expect(series, [200, 170, 200]);
    });

    test('empty points → empty series', () {
      expect(svc.balanceTrend(const [], 100), isEmpty);
    });
  });

  group('InsightsRange', () {
    test('windows are day-quantized and bucket correctly', () {
      final now = DateTime(2026, 7, 8, 14, 30);
      final (s7, e7) = InsightsRange.d7.window(now);
      expect(e7, DateTime(2026, 7, 8));
      expect(s7, DateTime(2026, 7, 2));
      expect(InsightsRange.d7.bucket, InsightsBucket.daily);
      expect(InsightsRange.m6.bucket, InsightsBucket.monthly);

      final (s6, _) = InsightsRange.m6.window(now);
      expect(s6, DateTime(2026, 2, 1)); // first day, 5 months back
    });
  });
}

final _epoch = DateTime(2026, 1, 1);
