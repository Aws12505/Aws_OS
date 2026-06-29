import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/recurrence.dart';
import 'tasks_dao.dart';

/// Turns persisted [TaskRecurrence] rows into concrete [Task] instances.
///
/// Mirrors the finance `RecurrenceService` pattern: each time it runs (on app
/// open / pull-to-refresh) it tops up the next [defaultWindow] of occurrences,
/// skipping any day that already has a task for that recurrence so it never
/// duplicates.
class TaskRecurrenceService {
  TaskRecurrenceService(this.dao);

  final TasksDao dao;

  static const Duration defaultWindow = Duration(days: 60);

  /// Materialize across every active recurrence.
  Future<void> materializeAll({Duration window = defaultWindow}) async {
    final all = await dao.watchRecurrences().first;
    for (final r in all) {
      if (r.endedAt != null) continue;
      await materializeFor(r.id, window: window);
    }
  }

  /// Create any missing task occurrences for [recurrenceId] within
  /// `[now, now + window]`.
  Future<void> materializeFor(String recurrenceId,
      {Duration window = defaultWindow}) async {
    final rec = await dao.getRecurrence(recurrenceId);
    if (rec == null || rec.endedAt != null) return;

    final rule = RecurrenceRule.parse(rec.ruleJson);
    final template = decodeTemplate(rec.templateJson);
    final workspaceId = template['workspaceId'] as String?;
    if (workspaceId == null) return;

    final from = DateTime.now();
    final to = from.add(window);

    final existing = await dao.getTasksForRecurrence(recurrenceId);
    final existingDays = existing
        .where((t) => t.dueAt != null)
        .map((t) => _dayKey(t.dueAt!))
        .toSet();

    final dates = nextOccurrences(
      rule: rule,
      start: rec.startDate,
      from: from,
      windowEnd: to,
      limit: 120,
    );

    for (final d in dates) {
      if (!existingDays.add(_dayKey(d))) continue;
      await dao.upsertTaskReturning(TasksCompanion(
        workspaceId: Value(workspaceId),
        title: Value(template['title'] as String? ?? 'Task'),
        bodyMd: Value(template['bodyMd'] as String?),
        category: Value(template['category'] as String?),
        dueAt: Value(d),
        recurrenceId: Value(recurrenceId),
      ));
    }

    // Cache the next upcoming occurrence (earliest >= now), or null.
    final next = dates.where((d) => !d.isBefore(from)).cast<DateTime?>().firstWhere(
          (d) => true,
          orElse: () => null,
        );
    await dao.updateRecurrenceNextDue(recurrenceId, next);
  }

  static int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  // -- Template helpers ----------------------------------------------------

  static String encodeTemplate({
    required String workspaceId,
    required String title,
    String? bodyMd,
    String? category,
  }) {
    return jsonEncode({
      'workspaceId': workspaceId,
      'title': title,
      'bodyMd': ?bodyMd,
      'category': ?category,
    });
  }

  static Map<String, dynamic> decodeTemplate(String json) =>
      jsonDecode(json) as Map<String, dynamic>;
}
