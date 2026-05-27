import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/tables/notes_tables.dart';

part 'notes_dao.g.dart';

@DriftAccessor(tables: [Notes, Tags, NoteTags])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  Stream<List<Note>> watchNotes() {
    return (select(notes)
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
        .watch();
  }

  Stream<List<Tag>> watchTags() {
    return (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  Stream<List<NoteTag>> watchNoteTags() {
    return select(noteTags).watch();
  }

  Future<Note?> getNote(String id) =>
      (select(notes)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Note> upsertNoteReturning(NotesCompanion n) async {
    final now = DateTime.now();
    return into(notes).insertReturning(
      n.copyWith(updatedAt: Value(now)),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> deleteNote(String id) =>
      (delete(notes)..where((t) => t.id.equals(id))).go();

  Future<Tag> upsertTagReturning(TagsCompanion t) async {
    final now = DateTime.now();
    return into(tags).insertReturning(
      t.copyWith(updatedAt: Value(now)),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> deleteTag(String id) =>
      (delete(tags)..where((t) => t.id.equals(id))).go();

  Future<void> replaceNoteTags(String noteId, List<String> tagIds) async {
    await transaction(() async {
      await (delete(noteTags)..where((t) => t.noteId.equals(noteId))).go();
      for (final tagId in tagIds) {
        await into(noteTags).insert(
          NoteTagsCompanion(noteId: Value(noteId), tagId: Value(tagId)),
        );
      }
    });
  }

  Future<List<String>> getTagIdsForNote(String noteId) async {
    final rows = await (select(noteTags)
          ..where((t) => t.noteId.equals(noteId)))
        .get();
    return rows.map((r) => r.tagId).toList();
  }
}
