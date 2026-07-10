import 'package:aws_os/core/db/app_database.dart';
import 'package:aws_os/features/notes/presentation/note_filter.dart';
import 'package:aws_os/features/notes/presentation/providers.dart';
import 'package:aws_os/features/notes/presentation/screens/notes_screen.dart';
import 'package:aws_os/shared/utils/date_preset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _base = DateTime(2026, 6, 1);

Note _note(String id, {String? title, DateTime? at}) => Note(
      id: id,
      createdAt: _base,
      updatedAt: _base,
      title: title,
      contentMd: 'body',
      occurredAt: at ?? _base,
      sortOrder: 0,
    );

void main() {
  group('NoteFilter.matches', () {
    test('default matches everything', () {
      const f = NoteFilter();
      expect(f.matches(_note('n'), const []), isTrue);
      expect(f.isDefault, isTrue);
      expect(f.activeCount, 0);
    });

    test('tag filter matches ANY selected tag', () {
      const f = NoteFilter(tagIds: {'t1'});
      expect(f.matches(_note('a'), ['t1', 't2']), isTrue);
      expect(f.matches(_note('b'), ['t3']), isFalse);
      expect(f.matches(_note('c'), const []), isFalse);
      expect(f.activeCount, 1);
    });

    test('multiple tags — any one is enough', () {
      const f = NoteFilter(tagIds: {'t1', 't2'});
      expect(f.matches(_note('a'), ['t2']), isTrue);
      expect(f.matches(_note('b'), ['t3']), isFalse);
    });

    test('untagged only', () {
      const f = NoteFilter(untaggedOnly: true);
      expect(f.matches(_note('a'), const []), isTrue);
      expect(f.matches(_note('b'), ['t1']), isFalse);
      expect(f.activeCount, 1);
    });

    test('custom date range', () {
      final f = const NoteFilter().copyWith(
        datePreset: DatePreset.custom,
        customFrom: DateTime(2026, 6, 1),
        customTo: DateTime(2026, 6, 30),
      );
      expect(f.matches(_note('a', at: DateTime(2026, 6, 15)), const []), isTrue);
      expect(
          f.matches(_note('b', at: DateTime(2026, 7, 15)), const []), isFalse);
    });
  });

  group('toggleTag', () {
    test('adds, then removes, and clears untagged-only', () {
      const f = NoteFilter(untaggedOnly: true);
      final added = f.toggleTag('t1');
      expect(added.tagIds, {'t1'});
      expect(added.untaggedOnly, isFalse);
      final removed = added.toggleTag('t1');
      expect(removed.tagIds, isEmpty);
      expect(removed.isDefault, isTrue);
    });
  });

  testWidgets('Notes list applies the tag filter', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notes = [
      _note('a', title: 'Alpha'),
      _note('b', title: 'Beta'),
    ];
    final tags = [
      Tag(id: 't1', createdAt: _base, updatedAt: _base, name: 'Work'),
    ];
    final mappings = [const NoteTag(noteId: 'a', tagId: 't1')];

    final container = ProviderContainer(overrides: [
      notesStreamProvider.overrideWith((ref) => Stream.value(notes)),
      tagsStreamProvider.overrideWith((ref) => Stream.value(tags)),
      noteTagsStreamProvider.overrideWith((ref) => Stream.value(mappings)),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NotesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);

    // Filter to tag t1 → only the tagged note ('Alpha') remains.
    container.read(noteFilterProvider.notifier).state =
        const NoteFilter(tagIds: {'t1'});
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
  });
}
