import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/tables/debrief_tables.dart';

part 'debrief_dao.g.dart';

@DriftAccessor(tables: [DebriefEntries])
class DebriefDao extends DatabaseAccessor<AppDatabase> with _$DebriefDaoMixin {
  DebriefDao(super.db);

  Stream<DebriefEntry?> watchEntry(String dayKey) {
    return (select(debriefEntries)..where((t) => t.dayKey.equals(dayKey)))
        .watchSingleOrNull();
  }

  Future<DebriefEntry?> getEntry(String dayKey) {
    return (select(debriefEntries)..where((t) => t.dayKey.equals(dayKey)))
        .getSingleOrNull();
  }

  Future<void> insertEntry(DebriefEntriesCompanion entry) {
    return into(debriefEntries).insert(entry);
  }

  Future<void> updateById(String id, DebriefEntriesCompanion patch) {
    return (update(debriefEntries)..where((t) => t.id.equals(id)))
        .write(patch.copyWith(updatedAt: Value(DateTime.now())));
  }

  Stream<List<DebriefEntry>> watchEntriesInRange(String fromKey, String toKey) {
    return (select(debriefEntries)
          ..where((t) =>
              t.dayKey.isBiggerOrEqualValue(fromKey) &
              t.dayKey.isSmallerOrEqualValue(toKey))
          ..orderBy([(t) => OrderingTerm.asc(t.dayKey)]))
        .watch();
  }
}
