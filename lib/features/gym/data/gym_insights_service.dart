import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_ext.dart';

/// One bucket of the "workouts over time" bar chart (a day or a week).
class GymBar {
  const GymBar({required this.start, required this.label, required this.value});
  final DateTime start;
  final String label;
  final double value;
}

/// Per-day session count over the range — feeds the consistency heatmap.
class GymDay {
  const GymDay({required this.date, required this.count});
  final DateTime date;
  final int count;
}

/// One point of a body-measurement series.
class MeasPoint {
  const MeasPoint({required this.date, required this.value});
  final DateTime date;
  final double value;
}

/// A body-measurement's values within the range, ascending by date.
class MeasurementSeries {
  const MeasurementSeries({required this.type, required this.points});
  final MeasurementType type;
  final List<MeasPoint> points;

  double get latest => points.last.value;
  double get first => points.first.value;
  double get change => latest - first;
  List<double> get values => [for (final p in points) p.value];
  List<String> get labels => [
    for (final p in points) DateFormat('d/M').format(p.date),
  ];
}

/// Chart-ready gym analytics for a selected range.
class GymInsights {
  const GymInsights({
    required this.bars,
    required this.days,
    required this.measurements,
    required this.sessions,
    required this.totalSessions,
    required this.activeDays,
    required this.sessionsPerWeek,
  });

  final List<GymBar> bars;
  final List<GymDay> days;
  final List<MeasurementSeries> measurements;

  /// In-range sessions, newest first — powers the history list.
  final List<DaySession> sessions;
  final int totalSessions;
  final int activeDays;
  final double sessionsPerWeek;

  bool get hasSessions => totalSessions > 0;
}

DateTime _mondayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Pure transforms from raw gym streams into the range-scoped series the gym
/// Insights tab renders. Mirrors the dashboard `InsightsService` convention.
class GymInsightsService {
  const GymInsightsService();

  GymInsights build({
    required List<DaySession> sessions,
    required List<MeasurementEntry> entries,
    required List<MeasurementValue> values,
    required List<MeasurementType> types,
    required DateTime start,
    required DateTime end,
    required bool daily,
  }) {
    final endInclusive = end.atEndOfDay;
    bool inRange(DateTime d) => !d.isBefore(start) && !d.isAfter(endInclusive);

    final inRangeSessions = sessions.where((s) => inRange(s.playedAt)).toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

    // Per-day counts across the whole window (zero-filled).
    final dayCount = <DateTime, int>{};
    for (final s in inRangeSessions) {
      final d = DateTime(s.playedAt.year, s.playedAt.month, s.playedAt.day);
      dayCount.update(d, (v) => v + 1, ifAbsent: () => 1);
    }
    final days = <GymDay>[];
    for (
      var d = DateTime(start.year, start.month, start.day);
      !d.isAfter(end);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      days.add(GymDay(date: d, count: dayCount[d] ?? 0));
    }

    // Bars: per-day for short ranges, per-week otherwise.
    final bars = <GymBar>[];
    if (daily) {
      for (final gd in days) {
        bars.add(
          GymBar(
            start: gd.date,
            label: DateFormat('E').format(gd.date),
            value: gd.count.toDouble(),
          ),
        );
      }
    } else {
      final weekCount = <DateTime, int>{};
      final weeks = <DateTime>[];
      for (
        var w = _mondayOf(start);
        !w.isAfter(end);
        w = DateTime(w.year, w.month, w.day + 7)
      ) {
        weeks.add(w);
        weekCount[w] = 0;
      }
      for (final s in inRangeSessions) {
        final wk = _mondayOf(
          DateTime(s.playedAt.year, s.playedAt.month, s.playedAt.day),
        );
        weekCount.update(wk, (v) => v + 1, ifAbsent: () => 1);
      }
      for (final wk in weeks) {
        bars.add(
          GymBar(
            start: wk,
            label: DateFormat('d/M').format(wk),
            value: (weekCount[wk] ?? 0).toDouble(),
          ),
        );
      }
    }

    // Measurement series within the range.
    final byEntry = <String, List<MeasurementValue>>{};
    for (final v in values) {
      byEntry.putIfAbsent(v.entryId, () => []).add(v);
    }
    final entriesAsc = entries.where((e) => inRange(e.takenAt)).toList()
      ..sort((a, b) => a.takenAt.compareTo(b.takenAt));
    final pointsByType = <String, List<MeasPoint>>{};
    for (final e in entriesAsc) {
      for (final v in (byEntry[e.id] ?? const <MeasurementValue>[])) {
        pointsByType
            .putIfAbsent(v.typeId, () => [])
            .add(MeasPoint(date: e.takenAt, value: v.value));
      }
    }
    final measurements = <MeasurementSeries>[
      for (final t in types)
        if ((pointsByType[t.id] ?? const []).isNotEmpty)
          MeasurementSeries(type: t, points: pointsByType[t.id]!),
    ];

    final spanDays =
        end.difference(DateTime(start.year, start.month, start.day)).inDays + 1;
    final weeksSpan = spanDays / 7;
    final perWeek = weeksSpan > 0 ? inRangeSessions.length / weeksSpan : 0.0;

    return GymInsights(
      bars: bars,
      days: days,
      measurements: measurements,
      sessions: inRangeSessions,
      totalSessions: inRangeSessions.length,
      activeDays: dayCount.length,
      sessionsPerWeek: perWeek,
    );
  }
}
