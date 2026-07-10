import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../shared/utils/date_preset.dart';

/// Structured filter for the notes list. Mirrors `TaskFilter`/`TransactionFilter`:
/// immutable, `copyWith` with sentinel-guarded nullables, `isDefault`/`activeCount`
/// for the UI, and a `matches` predicate. Free-text search stays in the view.
class NoteFilter {
  const NoteFilter({
    this.tagIds = const {},
    this.datePreset = DatePreset.all,
    this.customFrom,
    this.customTo,
    this.untaggedOnly = false,
  });

  /// Selected tag ids — a note matches if it carries ANY of them.
  final Set<String> tagIds;
  final DatePreset datePreset;
  final DateTime? customFrom;
  final DateTime? customTo;
  final bool untaggedOnly;

  bool get isDefault =>
      tagIds.isEmpty && datePreset == DatePreset.all && !untaggedOnly;

  int get activeCount {
    var n = 0;
    if (tagIds.isNotEmpty) n++;
    if (datePreset != DatePreset.all) n++;
    if (untaggedOnly) n++;
    return n;
  }

  bool matches(Note n, List<String> noteTags) {
    if (untaggedOnly && noteTags.isNotEmpty) return false;
    if (tagIds.isNotEmpty && !tagIds.any(noteTags.contains)) return false;
    final range = datePresetRange(
      datePreset,
      customFrom: customFrom,
      customTo: customTo,
    );
    if (range != null &&
        (n.occurredAt.isBefore(range.$1) || n.occurredAt.isAfter(range.$2))) {
      return false;
    }
    return true;
  }

  NoteFilter copyWith({
    Set<String>? tagIds,
    DatePreset? datePreset,
    Object? customFrom = _sentinel,
    Object? customTo = _sentinel,
    bool? untaggedOnly,
  }) {
    return NoteFilter(
      tagIds: tagIds ?? this.tagIds,
      datePreset: datePreset ?? this.datePreset,
      customFrom: customFrom == _sentinel
          ? this.customFrom
          : customFrom as DateTime?,
      customTo: customTo == _sentinel ? this.customTo : customTo as DateTime?,
      untaggedOnly: untaggedOnly ?? this.untaggedOnly,
    );
  }

  /// Toggle a tag id in/out of the selection; selecting a tag turns off the
  /// mutually-exclusive "untagged only" option.
  NoteFilter toggleTag(String id) {
    final next = {...tagIds};
    if (!next.add(id)) next.remove(id);
    return copyWith(tagIds: next, untaggedOnly: false);
  }
}

const _sentinel = Object();

final noteFilterProvider = StateProvider<NoteFilter>((_) => const NoteFilter());
