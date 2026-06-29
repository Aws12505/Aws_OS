import 'package:drift/drift.dart';

import '_syncable.dart';

/// One row per calendar day — the end-of-day "debrief".
///
/// [dayKey] is the local date as 'yyyy-MM-dd' and carries a UNIQUE constraint,
/// so there is at most one debrief per day. The UUID [id] from
/// [SyncableColumns] stays the primary key to keep the schema sync-ready.
class DebriefEntries extends Table with SyncableColumns {
  @override
  String get tableName => 'debrief_entries';

  TextColumn get dayKey => text().withLength(min: 10, max: 10)();

  IntColumn get mood => integer().nullable()(); // 1..5
  IntColumn get energy => integer().nullable()(); // 1..5

  TextColumn get wins => text().nullable()();
  TextColumn get improve => text().nullable()();
  TextColumn get gratitude => text().nullable()();
  TextColumn get reflection => text().nullable()();

  /// Cached narrative summary (AI-generated or rule-based) + when it was made.
  TextColumn get aiSummary => text().nullable()();
  DateTimeColumn get aiSummaryAt => dateTime().nullable()();

  /// Frozen JSON snapshot of the computed day stats, so a historical day's
  /// numbers stay stable even if older rows are edited later.
  TextColumn get statsJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {dayKey},
      ];
}
