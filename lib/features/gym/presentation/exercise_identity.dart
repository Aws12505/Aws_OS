import 'package:flutter/material.dart';

import '../../../shared/design/app_theme.dart';

/// A stable colour and monogram for an exercise name.
///
/// There is no exercise library and no bundled media, so openGym's animated
/// demonstrations are out of reach. This gets most of the same benefit for
/// nothing: the same movement looks the same everywhere it appears, so a
/// progression chip, a set card and a history sheet are recognizably about the
/// same lift without reading the label.
///
/// Matching is on the same normalized name the progression service uses, so a
/// stray capital or trailing space does not fork the identity.
abstract final class ExerciseIdentity {
  static String normalize(String name) => name.trim().toLowerCase();

  /// FNV-1a. Any stable hash works; `String.hashCode` does not, because Dart
  /// does not guarantee it across runs.
  static int _hash(String name) {
    var hash = 0x811c9dc5;
    for (final unit in normalize(name).codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  static Color colorOf(BuildContext context, String name) =>
      context.sem.chartAt(_hash(name));

  /// One or two letters. Two words give their initials, one word gives its
  /// first two letters, so "Bench press" reads BP and "Deadlift" reads DE.
  static String monogramOf(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final word = words.first;
      return (word.length == 1 ? word : word.substring(0, 2)).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }
}

/// The coloured monogram tile that goes in front of an exercise name.
class ExerciseAvatar extends StatelessWidget {
  const ExerciseAvatar({super.key, required this.name, this.size = 30});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final role = SemanticRole.derive(
      ExerciseIdentity.colorOf(context, name),
      cs,
    );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: role.container,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        ExerciseIdentity.monogramOf(name),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: role.onContainer,
          letterSpacing: 0,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
