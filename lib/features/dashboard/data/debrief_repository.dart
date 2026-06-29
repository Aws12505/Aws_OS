import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_ext.dart';
import 'debrief_dao.dart';

/// Day-keyed access to debrief entries. Upserts are read-modify-write keyed on
/// the day so partial saves (journal vs. AI summary vs. stats) don't clobber
/// each other.
class DebriefRepository {
  DebriefRepository(this.dao);
  final DebriefDao dao;

  Stream<DebriefEntry?> watchEntry(DateTime date) =>
      dao.watchEntry(date.dayKey);

  Future<DebriefEntry?> getEntry(DateTime date) => dao.getEntry(date.dayKey);

  Stream<List<DebriefEntry>> watchRange(DateTime from, DateTime to) =>
      dao.watchEntriesInRange(from.dayKey, to.dayKey);

  /// Save the whole journal portion for [date] (mood/energy + reflections).
  Future<void> saveReflection(
    DateTime date, {
    int? mood,
    int? energy,
    String? wins,
    String? improve,
    String? gratitude,
    String? reflection,
  }) {
    return _upsert(
      date,
      DebriefEntriesCompanion(
        mood: Value(mood),
        energy: Value(energy),
        wins: Value(wins),
        improve: Value(improve),
        gratitude: Value(gratitude),
        reflection: Value(reflection),
      ),
    );
  }

  Future<void> cacheAiSummary(DateTime date, String summary) {
    return _upsert(
      date,
      DebriefEntriesCompanion(
        aiSummary: Value(summary),
        aiSummaryAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> cacheStatsSnapshot(DateTime date, String statsJson) {
    return _upsert(date, DebriefEntriesCompanion(statsJson: Value(statsJson)));
  }

  Future<void> _upsert(DateTime date, DebriefEntriesCompanion patch) async {
    final key = date.dayKey;
    final existing = await dao.getEntry(key);
    if (existing == null) {
      await dao.insertEntry(patch.copyWith(dayKey: Value(key)));
    } else {
      await dao.updateById(existing.id, patch);
    }
  }
}
