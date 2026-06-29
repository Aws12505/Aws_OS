import 'package:flutter/material.dart';

import '../../core/utils/date_ext.dart';

/// Pick a date and then a time, combined into one [DateTime].
///
/// Returns null if the user cancels the date step. If they cancel only the time
/// step, the chosen date keeps the initial time-of-day. Centralizes the
/// two-dialog pattern repeated across the form sheets.
Future<DateTime?> pickDateTime(
  BuildContext context, {
  DateTime? initial,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final base = initial ?? DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: base,
    firstDate: firstDate ?? DateTime(2000),
    lastDate: lastDate ?? DateTime(2100),
  );
  if (date == null) return null;
  if (!context.mounted) return date.withTimeOf(base);
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(base),
  );
  final h = time?.hour ?? base.hour;
  final m = time?.minute ?? base.minute;
  return DateTime(date.year, date.month, date.day, h, m);
}

/// Pick just a date, returned at start-of-day.
Future<DateTime?> pickDate(
  BuildContext context, {
  DateTime? initial,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now(),
    firstDate: firstDate ?? DateTime(2000),
    lastDate: lastDate ?? DateTime(2100),
  );
  return picked?.atStartOfDay;
}
