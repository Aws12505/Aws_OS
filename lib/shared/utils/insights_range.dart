import '../../core/utils/date_ext.dart';

/// The time windows the Insights dashboard can scope its charts to.
enum InsightsRange { d7, d30, m3, m6 }

/// How a range's days are grouped for bar/line buckets.
enum InsightsBucket { daily, monthly }

extension InsightsRangeX on InsightsRange {
  String get label => switch (this) {
    InsightsRange.d7 => '7D',
    InsightsRange.d30 => '30D',
    InsightsRange.m3 => '3M',
    InsightsRange.m6 => '6M',
  };

  InsightsBucket get bucket => switch (this) {
    InsightsRange.d7 || InsightsRange.d30 => InsightsBucket.daily,
    InsightsRange.m3 || InsightsRange.m6 => InsightsBucket.monthly,
  };

  /// Inclusive `(start, end)` at day granularity for [now]. Day-quantized so it
  /// stays stable as a Riverpod family key across rebuilds within the same day
  /// (otherwise `DateTime.now()` would mint a fresh key every build).
  (DateTime start, DateTime end) window(DateTime now) {
    final end = now.atStartOfDay;
    final start = switch (this) {
      InsightsRange.d7 => end.addDays(-6),
      InsightsRange.d30 => end.addDays(-29),
      InsightsRange.m3 => DateTime(end.year, end.month - 2, 1),
      InsightsRange.m6 => DateTime(end.year, end.month - 5, 1),
    };
    return (start, end);
  }
}
