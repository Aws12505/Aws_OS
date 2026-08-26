import 'package:flutter/material.dart';

import 'color_ops.dart';
import 'tokens.dart';

/// One semantic color, resolved four ways.
///
/// The app uses these colors in two different jobs, and a single hex cannot do
/// both: as foreground (text and icons on a surface, which needs 4.5:1) and as
/// a chip or badge tint (which needs its own readable foreground). Deriving all
/// four up front is what makes the dark theme legible without changing the
/// palette's identity.
@immutable
class SemanticRole {
  const SemanticRole({
    required this.base,
    required this.fg,
    required this.container,
    required this.onContainer,
  });

  /// Chart strokes and fills, large glyphs. 3:1 against the surface.
  final Color base;

  /// Text and icons directly on the surface. 4.5:1.
  final Color fg;

  /// Opaque chip/badge fill, pre-blended so contrast is guaranteed rather than
  /// depending on whatever happens to be behind a translucent card.
  final Color container;

  /// Text and icons on [container]. 4.5:1.
  final Color onContainer;

  /// Four contrast searches per role, so the result is memoized: this is
  /// called from `build` in pills, badges, avatars and chart cards.
  factory SemanticRole.derive(Color brand, ColorScheme cs) {
    final key = (brand.toARGB32(), cs.surface.toARGB32(), cs.brightness);
    final hit = _roleCache[key];
    if (hit != null) return hit;
    if (_roleCache.length > 256) _roleCache.clear();
    return _roleCache[key] = SemanticRole._derive(brand, cs);
  }

  static final Map<(int, int, Brightness), SemanticRole> _roleCache = {};

  factory SemanticRole._derive(Color brand, ColorScheme cs) {
    final dark = cs.brightness == Brightness.dark;
    final container = blendOver(
      brand,
      cs.surfaceContainerLow,
      dark ? 0.22 : 0.14,
    );
    return SemanticRole(
      base: readableOn(brand, cs.surface, minContrast: 3.0),
      fg: readableOn(brand, cs.surface, minContrast: 4.5),
      container: container,
      onContainer: readableOn(brand, container, minContrast: 4.5),
    );
  }

  static SemanticRole lerp(SemanticRole a, SemanticRole b, double t) =>
      SemanticRole(
        base: Color.lerp(a.base, b.base, t)!,
        fg: Color.lerp(a.fg, b.fg, t)!,
        container: Color.lerp(a.container, b.container, t)!,
        onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
      );
}

/// Brightness-aware replacements for the const [DomainColors], [MoodColors] and
/// [ChartPalette].
///
/// Semantic roles deliberately do NOT follow the user's chosen seed. Nudging
/// income-green or expense-red toward a purple seed would destroy the only
/// thing those colors exist to communicate. [chart] is the exception: those
/// colors are categorical and carry no intrinsic meaning, so a small hue nudge
/// toward the seed ties the charts to the theme.
@immutable
class AppSemantics {
  const AppSemantics({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.exchange,
    required this.tasks,
    required this.notes,
    required this.gym,
    required this.warning,
    required this.positive,
    required this.neutral,
    required this.mood,
    required this.chart,
    required this.onAccent,
    required this.onPrimary,
  });

  final SemanticRole income;
  final SemanticRole expense;
  final SemanticRole transfer;
  final SemanticRole exchange;
  final SemanticRole tasks;
  final SemanticRole notes;
  final SemanticRole gym;
  final SemanticRole warning;
  final SemanticRole positive;
  final SemanticRole neutral;

  /// 1..5 mood ramp. Always render alongside [MoodColors.labelForScore] —
  /// a red-to-green ramp alone is unreadable with deuteranopia.
  final List<Color> mood;

  /// Categorical chart palette, seed-nudged and contrast-corrected.
  final List<Color> chart;

  /// Foreground that stays readable on the user's chosen accent and primary,
  /// whatever they picked.
  final Color onAccent;
  final Color onPrimary;

  factory AppSemantics.fromScheme(ColorScheme cs) {
    SemanticRole r(Color c) => SemanticRole.derive(c, cs);
    return AppSemantics(
      income: r(DomainColors.income),
      expense: r(DomainColors.expense),
      transfer: r(DomainColors.transfer),
      exchange: r(DomainColors.exchange),
      tasks: r(DomainColors.tasks),
      notes: r(DomainColors.notes),
      gym: r(DomainColors.gym),
      warning: r(DomainColors.warning),
      positive: r(DomainColors.positive),
      neutral: r(DomainColors.neutral),
      mood: [
        for (final c in MoodColors.ramp)
          readableOn(c, cs.surface, minContrast: 3.0),
      ],
      chart: [
        for (final c in ChartPalette.colors)
          readableOn(
            nudgeHueToward(c, cs.primary, 0.12),
            cs.surface,
            minContrast: 3.0,
          ),
      ],
      onAccent: bestForegroundOn(cs.secondary),
      onPrimary: bestForegroundOn(cs.primary),
    );
  }

  /// Role for a transaction kind, mirroring [DomainColors.forTxKind] so callers
  /// can migrate one at a time.
  SemanticRole forTxKind(String kind) => switch (kind) {
    'income' => income,
    'expense' => expense,
    'transfer' => transfer,
    'exchange' => exchange,
    _ => neutral,
  };

  Color chartAt(int index) => chart[index % chart.length];

  Color moodForScore(int score) => mood[score.clamp(1, 5) - 1];

  static List<Color> _lerpColors(List<Color> a, List<Color> b, double t) => [
    for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!,
  ];

  static AppSemantics lerp(AppSemantics a, AppSemantics b, double t) =>
      AppSemantics(
        income: SemanticRole.lerp(a.income, b.income, t),
        expense: SemanticRole.lerp(a.expense, b.expense, t),
        transfer: SemanticRole.lerp(a.transfer, b.transfer, t),
        exchange: SemanticRole.lerp(a.exchange, b.exchange, t),
        tasks: SemanticRole.lerp(a.tasks, b.tasks, t),
        notes: SemanticRole.lerp(a.notes, b.notes, t),
        gym: SemanticRole.lerp(a.gym, b.gym, t),
        warning: SemanticRole.lerp(a.warning, b.warning, t),
        positive: SemanticRole.lerp(a.positive, b.positive, t),
        neutral: SemanticRole.lerp(a.neutral, b.neutral, t),
        mood: _lerpColors(a.mood, b.mood, t),
        chart: _lerpColors(a.chart, b.chart, t),
        onAccent: Color.lerp(a.onAccent, b.onAccent, t)!,
        onPrimary: Color.lerp(a.onPrimary, b.onPrimary, t)!,
      );
}
