import 'package:aws_os/core/utils/date_ext.dart';

enum DatePreset { all, today, thisWeek, thisMonth, custom }

extension DatePresetX on DatePreset {
  String get label => switch (this) {
        DatePreset.all => 'All',
        DatePreset.today => 'Today',
        DatePreset.thisWeek => 'This Week',
        DatePreset.thisMonth => 'This Month',
        DatePreset.custom => 'Custom',
      };
}

/// Returns `(from, to)` inclusive range for the preset, or null for [DatePreset.all].
(DateTime, DateTime)? datePresetRange(
  DatePreset preset, {
  DateTime? customFrom,
  DateTime? customTo,
}) {
  final now = DateTime.now();
  return switch (preset) {
    DatePreset.all => null,
    DatePreset.today => (now.atStartOfDay, now.atEndOfDay),
    DatePreset.thisWeek => (
        now.atStartOfDay.addDays(-(now.weekday - 1)),
        now.atStartOfDay.addDays(7 - now.weekday).atEndOfDay,
      ),
    DatePreset.thisMonth => (
        DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month + 1, 1)
            .addDays(-1)
            .atEndOfDay,
      ),
    DatePreset.custom => (customFrom ?? now.atStartOfDay, customTo ?? now.atEndOfDay),
  };
}
