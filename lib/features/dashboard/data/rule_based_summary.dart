import 'day_summary.dart';

/// Offline narrative summary of a day. This is the default when AI is disabled
/// and the fallback when an AI call fails — so a summary always lands.
abstract final class RuleBasedSummary {
  static String build(DaySummary s) {
    final parts = <String>[];

    if (s.tasksDue > 0) {
      final pct = (s.taskCompletion * 100).round();
      parts.add('Completed ${s.tasksDone}/${s.tasksDue} tasks ($pct%).');
    } else {
      parts.add('No tasks were due.');
    }

    if (s.transactionCount > 0) {
      final net = s.netByCurrency.entries
          .map((e) {
            final sign = e.value > 0 ? '+' : '';
            return '$sign${e.value.toStringAsFixed(2)} ${e.key}';
          })
          .join(', ');
      final top = s.topExpenseCategories.isNotEmpty
          ? ' Top spend: ${s.topExpenseCategories.first.name}.'
          : '';
      final plural = s.transactionCount == 1 ? '' : 's';
      parts.add('${s.transactionCount} transaction$plural (net $net).$top');
    }

    parts.add(s.workedOut ? 'Logged a workout. Nice.' : 'No workout logged.');

    if (s.notesCount > 0) {
      final plural = s.notesCount == 1 ? '' : 's';
      parts.add('Wrote ${s.notesCount} note$plural.');
    }

    final mood = s.debrief?.mood;
    if (mood != null) parts.add('Mood $mood/5.');
    final energy = s.debrief?.energy;
    if (energy != null) parts.add('Energy $energy/5.');

    if (s.taskStreak >= 3) parts.add('${s.taskStreak}-day task streak.');

    // A gentle nudge for tomorrow.
    if (s.tasksDue > 0 && s.taskCompletion < 0.5) {
      parts.add('Tomorrow, clear the unfinished tasks first.');
    } else if (!s.workedOut) {
      parts.add('Maybe fit in a short workout tomorrow.');
    }

    return parts.join(' ');
  }
}
