import 'package:aws_os/core/utils/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecurrenceRule', () {
    test('serializes round-trip', () {
      final rule = RecurrenceRule(
        freq: RecurrenceFreq.weekly,
        interval: 2,
        byWeekday: const [1, 3, 5],
        until: DateTime(2026, 12, 31),
      );
      final parsed = RecurrenceRule.parse(rule.toJson());
      expect(parsed.freq, RecurrenceFreq.weekly);
      expect(parsed.interval, 2);
      expect(parsed.byWeekday, [1, 3, 5]);
      expect(parsed.until, DateTime(2026, 12, 31));
    });

    test('daily occurrences', () {
      final rule = const RecurrenceRule(freq: RecurrenceFreq.daily);
      final start = DateTime(2026, 1, 1);
      final out = nextOccurrences(
        rule: rule,
        start: start,
        from: start,
        windowEnd: start.add(const Duration(days: 4)),
      );
      expect(out.length, 5);
      expect(out.first, start);
      expect(out.last, start.add(const Duration(days: 4)));
    });

    test('monthly steps add months', () {
      final start = DateTime(2026, 1, 15);
      final rule = const RecurrenceRule(freq: RecurrenceFreq.monthly);
      final out = nextOccurrences(
        rule: rule,
        start: start,
        from: start,
        windowEnd: DateTime(2026, 6, 1),
      );
      expect(out.map((d) => d.month).toList(), [1, 2, 3, 4, 5]);
    });

    test('weekly with byWeekday respects selection', () {
      // Start on a Monday; want Mon + Wed.
      final start = DateTime(2026, 1, 5); // Mon
      final rule = const RecurrenceRule(
        freq: RecurrenceFreq.weekly,
        byWeekday: [1, 3],
      );
      final out = nextOccurrences(
        rule: rule,
        start: start,
        from: start,
        windowEnd: start.add(const Duration(days: 9)),
      );
      // Mon 5, Wed 7, Mon 12, Wed 14
      expect(out.length, 4);
      expect(out[0].weekday, DateTime.monday);
      expect(out[1].weekday, DateTime.wednesday);
    });

    test('until stops the iteration', () {
      final start = DateTime(2026, 1, 1);
      final rule = RecurrenceRule(
        freq: RecurrenceFreq.daily,
        until: DateTime(2026, 1, 3),
      );
      final out = nextOccurrences(
        rule: rule,
        start: start,
        from: start,
        windowEnd: DateTime(2026, 12, 31),
      );
      expect(out.length, 3);
    });
  });
}
