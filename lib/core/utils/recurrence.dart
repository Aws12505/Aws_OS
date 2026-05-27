import 'dart:convert';

import 'date_ext.dart';

enum RecurrenceFreq { daily, weekly, monthly, yearly }

/// RRULE-lite recurrence rule. Stored in DB as JSON via [toJson] / [parse].
/// Pure / unit-testable; no DB or time-zone dependency beyond `DateTime`.
class RecurrenceRule {
  const RecurrenceRule({
    required this.freq,
    this.interval = 1,
    this.byWeekday = const [],
    this.until,
  })  : assert(interval >= 1);

  final RecurrenceFreq freq;
  final int interval;
  /// ISO 8601 weekdays: 1 = Monday … 7 = Sunday. Only used when freq=weekly.
  final List<int> byWeekday;
  final DateTime? until;

  Map<String, dynamic> toMap() => {
        'freq': freq.name,
        'interval': interval,
        if (byWeekday.isNotEmpty) 'byWeekday': byWeekday,
        if (until != null) 'until': until!.toIso8601String(),
      };

  String toJson() => jsonEncode(toMap());

  static RecurrenceRule parse(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    return RecurrenceRule(
      freq: RecurrenceFreq.values.firstWhere((f) => f.name == m['freq']),
      interval: (m['interval'] as num?)?.toInt() ?? 1,
      byWeekday: (m['byWeekday'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
      until: m['until'] == null ? null : DateTime.parse(m['until'] as String),
    );
  }
}

/// Generate occurrence dates >= [from] and <= optional [windowEnd], starting
/// the recurrence cycle at [start]. Stops at `rule.until` (inclusive) or
/// after [limit] occurrences, whichever comes first.
List<DateTime> nextOccurrences({
  required RecurrenceRule rule,
  required DateTime start,
  required DateTime from,
  DateTime? windowEnd,
  int limit = 365,
}) {
  final List<DateTime> out = [];
  final hardEnd = rule.until;
  // Walk candidates starting from `start` and step by interval until we pass
  // windowEnd or hit limit.
  DateTime cursor = start;
  int safety = 0;
  while (out.length < limit && safety < 20000) {
    safety++;
    if (hardEnd != null && cursor.isAfter(hardEnd)) break;
    if (windowEnd != null && cursor.isAfter(windowEnd)) break;
    final include = !cursor.isBefore(from);
    if (include) {
      if (rule.freq == RecurrenceFreq.weekly && rule.byWeekday.isNotEmpty) {
        if (rule.byWeekday.contains(cursor.weekday)) out.add(cursor);
      } else {
        out.add(cursor);
      }
    }
    cursor = _advance(cursor, rule);
  }
  return out;
}

DateTime _advance(DateTime cursor, RecurrenceRule rule) {
  switch (rule.freq) {
    case RecurrenceFreq.daily:
      return cursor.addDays(rule.interval);
    case RecurrenceFreq.weekly:
      // If specific weekdays are requested, step one day at a time inside the
      // current week; jump `interval` weeks when wrapping past Sunday.
      if (rule.byWeekday.isNotEmpty) {
        final next = cursor.addDays(1);
        if (next.weekday == DateTime.monday && rule.interval > 1) {
          return cursor.addDays(1 + 7 * (rule.interval - 1));
        }
        return next;
      }
      return cursor.addDays(7 * rule.interval);
    case RecurrenceFreq.monthly:
      return DateTime(cursor.year, cursor.month + rule.interval, cursor.day,
          cursor.hour, cursor.minute, cursor.second);
    case RecurrenceFreq.yearly:
      return DateTime(cursor.year + rule.interval, cursor.month, cursor.day,
          cursor.hour, cursor.minute, cursor.second);
  }
}
