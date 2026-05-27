extension DateTimeX on DateTime {
  /// Truncate to local-midnight start of day.
  DateTime get atStartOfDay => DateTime(year, month, day);

  /// Last instant of the local day (millisecond precision).
  DateTime get atEndOfDay =>
      DateTime(year, month, day, 23, 59, 59, 999);

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  DateTime addDays(int days) => DateTime(year, month, day + days, hour, minute,
      second, millisecond, microsecond);

  /// Combine the date part of `this` with the time-of-day from `other`.
  DateTime withTimeOf(DateTime other) =>
      DateTime(year, month, day, other.hour, other.minute, other.second);
}
