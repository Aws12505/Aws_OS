import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import 'notes_dao.dart';

class NotesRepository {
  NotesRepository(this.dao);
  final NotesDao dao;

  Stream<List<Note>> watchNotes() => dao.watchNotes();
  Stream<List<Tag>> watchTags() => dao.watchTags();
  Stream<List<NoteTag>> watchNoteTags() => dao.watchNoteTags();
  Future<Note?> getNote(String id) => dao.getNote(id);
  Future<List<String>> getTagIdsForNote(String id) =>
      dao.getTagIdsForNote(id);

  Future<Note> saveNote({
    String? id,
    String? title,
    required String contentMd,
    required DateTime occurredAt,
    required List<String> tagIds,
  }) async {
    final saved = await dao.upsertNoteReturning(NotesCompanion(
      id: id == null ? const Value.absent() : Value(id),
      title: Value(title),
      contentMd: Value(contentMd),
      occurredAt: Value(occurredAt),
    ));
    await dao.replaceNoteTags(saved.id, tagIds);
    return saved;
  }

  Future<void> deleteNote(String id) => dao.deleteNote(id);

  Future<Tag> saveTag({String? id, required String name, int? color}) {
    return dao.upsertTagReturning(TagsCompanion(
      id: id == null ? const Value.absent() : Value(id),
      name: Value(name),
      color: Value(color),
    ));
  }

  Future<void> deleteTag(String id) => dao.deleteTag(id);
}
