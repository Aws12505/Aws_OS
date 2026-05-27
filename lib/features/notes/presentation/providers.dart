import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../data/notes_dao.dart';
import '../data/notes_repository.dart';

final notesDaoProvider = Provider<NotesDao>((ref) {
  return NotesDao(ref.watch(databaseProvider));
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(ref.watch(notesDaoProvider));
});

final notesStreamProvider = StreamProvider<List<Note>>((ref) {
  return ref.watch(notesRepositoryProvider).watchNotes();
});

final tagsStreamProvider = StreamProvider<List<Tag>>((ref) {
  return ref.watch(notesRepositoryProvider).watchTags();
});

final noteTagsStreamProvider = StreamProvider<List<NoteTag>>((ref) {
  return ref.watch(notesRepositoryProvider).watchNoteTags();
});
