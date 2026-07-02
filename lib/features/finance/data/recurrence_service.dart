import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/tables/_syncable.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/recurrence.dart';
import 'finance_dao.dart';
import 'finance_repository.dart';

/// Bridges the pure [RecurrenceRule] engine with persisted recurrences and
/// the queue of `scheduled_occurrences` that the dashboard surfaces.
class RecurrenceService {
  RecurrenceService(this.dao, this.repo, this.notifications);

  final FinanceDao dao;
  final FinanceRepository repo;
  final NotificationService notifications;

  /// Time of day at which reminders fire. The settings layer keeps this in
  /// sync via [setReminderTime] — defaults to 9:00 AM.
  int _reminderHour = 9;
  int _reminderMinute = 0;

  void setReminderTime(int hour, int minute) {
    _reminderHour = hour;
    _reminderMinute = minute;
  }

  static const Duration defaultWindow = Duration(days: 30);

  /// Re-materialize the pending occurrence queue for [recurrenceId] within
  /// `[now, now + window]`. Existing pending rows in range are kept;
  /// duplicates are avoided. Confirmed/skipped rows are never touched.
  Future<void> materializeFor(String recurrenceId,
      {Duration window = defaultWindow}) async {
    final rec = await dao.getRecurrence(recurrenceId);
    if (rec == null) return;
    if (rec.endedAt != null) return;
    final rule = RecurrenceRule.parse(rec.ruleJson);

    final from = DateTime.now();
    final to = from.add(window);
    final existing = await dao
        .getOccurrencesForRecurrenceInRange(recurrenceId, from, to);
    final existingKeys =
        existing.map((o) => o.dueAt.millisecondsSinceEpoch).toSet();

    final dates = nextOccurrences(
      rule: rule,
      start: rec.startDate,
      from: from,
      windowEnd: to,
      limit: 60,
    );

    for (final d in dates) {
      if (existingKeys.contains(d.millisecondsSinceEpoch)) continue;
      final id = newUuid();
      await dao.insertOccurrence(ScheduledOccurrencesCompanion(
        id: Value(id),
        recurrenceId: Value(recurrenceId),
        dueAt: Value(d),
        status: const Value('pending'),
      ));
      final occ = await dao.getOccurrence(id);
      if (occ != null) {
        await notifications.scheduleForOccurrence(
          occ,
          reminderHour: _reminderHour,
          reminderMinute: _reminderMinute,
          preview: _previewFor(rec),
        );
      }
    }

    // Persist `next_due_at` to the earliest future pending due (or null).
    final future = await dao.getOccurrencesForRecurrenceInRange(
        recurrenceId, from, to.add(const Duration(days: 365)));
    DateTime? next;
    for (final o in future) {
      if (o.status == 'pending') {
        next = o.dueAt;
        break;
      }
    }
    await dao.updateRecurrenceNextDue(recurrenceId, next);
  }

  /// Materialize across every active recurrence.
  Future<void> materializeAll({Duration window = defaultWindow}) async {
    final all = await dao.watchRecurrences().first;
    for (final r in all) {
      if (r.endedAt != null) continue;
      await materializeFor(r.id, window: window);
    }
  }

  /// Confirm a pending occurrence by writing the actual transaction and
  /// flipping the row to `confirmed`. The caller may override the template's
  /// legs / note (recurring amounts can vary per occurrence).
  Future<String?> confirmOccurrence(
    String occurrenceId, {
    List<TxLegDraft>? overrideLegs,
    String? overrideNote,
    DateTime? overrideDate,
  }) async {
    final occ = await dao.getOccurrence(occurrenceId);
    if (occ == null) return null;
    final rec = await dao.getRecurrence(occ.recurrenceId);
    if (rec == null) return null;

    final legs = overrideLegs ?? _decodeTemplateLegs(rec.templateLegsJson);
    final note = overrideNote ?? rec.noteTemplate;
    final date = overrideDate ?? occ.dueAt;

    final txId = await repo.recordIncomeOrExpense(
      kind: rec.kind,
      occurredAt: date,
      legs: legs,
      note: note,
      categoryId: rec.categoryId,
      typeId: rec.typeId,
      recurrenceId: rec.id,
      scheduledOccurrenceId: occurrenceId,
    );
    await dao.markOccurrenceStatus(occurrenceId, 'confirmed', txId);
    await notifications.cancelForOccurrence(occurrenceId);
    return txId;
  }

  Future<void> skipOccurrence(String occurrenceId) async {
    await dao.markOccurrenceStatus(occurrenceId, 'skipped', null);
    await notifications.cancelForOccurrence(occurrenceId);
  }

  String _previewFor(Recurrence rec) {
    final kindLabel = rec.kind == 'expense' ? 'Expense' : 'Income';
    final note = rec.noteTemplate?.trim();
    return note != null && note.isNotEmpty
        ? '$kindLabel: $note'
        : '$kindLabel pending — tap to confirm or skip.';
  }

  // -- Template helpers ----------------------------------------------------

  static String encodeTemplateLegs(List<TxLegDraft> legs) {
    return jsonEncode([
      for (final l in legs)
        {
          'accountId': l.accountId,
          'currencyId': l.currencyId,
          'amount': l.amount,
        },
    ]);
  }

  static List<TxLegDraft> _decodeTemplateLegs(String json) {
    final raw = jsonDecode(json) as List;
    return [
      for (final e in raw)
        TxLegDraft(
          accountId: (e as Map)['accountId'] as String,
          currencyId: e['currencyId'] as String,
          amount: (e['amount'] as num).toDouble(),
        ),
    ];
  }

  static List<TxLegDraft> decodeTemplateLegs(String json) =>
      _decodeTemplateLegs(json);
}
