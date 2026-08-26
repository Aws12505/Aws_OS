import 'package:flutter/material.dart';

/// Spacing scale in logical pixels. Use these instead of ad-hoc literals so the
/// vertical/horizontal rhythm stays consistent across every screen.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Corner-radius scale.
///
/// Every corner in the app snaps to one of these. Before this, sixteen distinct
/// literals were in use (2, 3, 4, 6, 7, 9, 10, 11, 13, 14 among them), which is
/// not a shape system, it is an accident.
abstract final class AppRadius {
  /// Bars, dots, tiny indicators.
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 22;
  static const double pill = 28;
}

/// Fixed-chrome clearances.
abstract final class AppInsets {
  /// Bottom padding a scrolling list needs to clear the translucent nav bar
  /// and the floating action button. Replaces the three different magic
  /// numbers (110, 120, 156) that were all reaching for the same clearance.
  static const double listBottom = 120;

  /// Same clearance for a screen with no floating action button over it.
  static const double listBottomNoFab = 96;
}

/// Semantic domain colors — the single source of truth for the literals that
/// were previously copy-pasted across dashboard_screen, quick_action_fab and
/// notes_screen.
abstract final class DomainColors {
  static const Color income = Color(0xFF22C55E);
  static const Color expense = Color(0xFFEF4444);
  static const Color transfer = Color(0xFF3B82F6);
  static const Color exchange = Color(0xFF8B5CF6);
  static const Color tasks = Color(0xFF14B8A6);
  static const Color notes = Color(0xFF8B5CF6);
  static const Color gym = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color positive = Color(0xFF22C55E);
  static const Color neutral = Color(0xFF6B7280);

  /// Color for a transaction kind ('income' | 'expense' | 'transfer' | 'exchange').
  static Color forTxKind(String kind) => switch (kind) {
        'income' => income,
        'expense' => expense,
        'transfer' => transfer,
        'exchange' => exchange,
        _ => neutral,
      };

  /// Icon for a transaction kind, kept next to the color so callers stay consistent.
  static IconData iconForTxKind(String kind) => switch (kind) {
        'income' => Icons.trending_up_rounded,
        'expense' => Icons.trending_down_rounded,
        'transfer' => Icons.compare_arrows_rounded,
        'exchange' => Icons.swap_horiz_rounded,
        _ => Icons.receipt_long_rounded,
      };

  static String labelForTxKind(String kind) =>
      kind.isEmpty ? kind : kind[0].toUpperCase() + kind.substring(1);
}

/// 1..5 mood/energy ramp (red → green) for the debrief journal.
abstract final class MoodColors {
  static const List<Color> ramp = [
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFFEAB308),
    Color(0xFF84CC16),
    Color(0xFF22C55E),
  ];

  static Color forScore(int score) => ramp[score.clamp(1, 5) - 1];

  static const List<String> labels = [
    'Rough',
    'Low',
    'Okay',
    'Good',
    'Great',
  ];

  static String labelForScore(int score) => labels[score.clamp(1, 5) - 1];
}

/// Categorical palette for charts (pies, bars, lines). Cycles when exhausted.
abstract final class ChartPalette {
  static const List<Color> colors = [
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFF22C55E),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
  ];

  static Color at(int index) => colors[index % colors.length];
}
