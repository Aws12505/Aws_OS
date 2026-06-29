// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'debrief_dao.dart';

// ignore_for_file: type=lint
mixin _$DebriefDaoMixin on DatabaseAccessor<AppDatabase> {
  $DebriefEntriesTable get debriefEntries => attachedDatabase.debriefEntries;
  DebriefDaoManager get managers => DebriefDaoManager(this);
}

class DebriefDaoManager {
  final _$DebriefDaoMixin _db;
  DebriefDaoManager(this._db);
  $$DebriefEntriesTableTableManager get debriefEntries =>
      $$DebriefEntriesTableTableManager(
        _db.attachedDatabase,
        _db.debriefEntries,
      );
}
