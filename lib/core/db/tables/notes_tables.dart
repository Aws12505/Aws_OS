import 'package:drift/drift.dart';

import '_syncable.dart';

class Notes extends Table with SyncableColumns {
  @override
  String get tableName => 'notes';

  TextColumn get title => text().nullable()();
  TextColumn get contentMd => text()();
  DateTimeColumn get occurredAt => dateTime()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table with SyncableColumns {
  @override
  String get tableName => 'tags';

  TextColumn get name => text()();
  IntColumn get color => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class NoteTags extends Table {
  @override
  String get tableName => 'note_tags';

  TextColumn get noteId => text().customConstraint(
      'NOT NULL REFERENCES notes(id) ON DELETE CASCADE')();
  TextColumn get tagId => text().customConstraint(
      'NOT NULL REFERENCES tags(id) ON DELETE CASCADE')();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}
