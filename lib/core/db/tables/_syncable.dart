import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newUuid() => _uuid.v4();

/// Shared columns for every domain row. UUID PK + creation/update timestamps
/// keep the schema sync-ready for a future backend.
mixin SyncableColumns on Table {
  TextColumn get id => text().clientDefault(newUuid)();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();
}
