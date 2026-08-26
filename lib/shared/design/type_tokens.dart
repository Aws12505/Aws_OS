import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The full type scale, resolved once per theme build.
///
/// Why this exists in this shape, and not as a set of weight/tracking presets
/// applied with `copyWith`:
///
/// `GoogleFonts.getTextTheme(family, base)` bakes a single variant name (for
/// example `Inter_500`) into every style and downloads only that file. Every
/// later `copyWith(fontWeight: FontWeight.w700)` then asks for a bold face from
/// a family that contains no bold face, so the engine synthesizes one. That is
/// what made every heading in the app look mushy.
///
/// Building each style through `GoogleFonts.getFont(family, fontWeight: w)`
/// loads the real file for that weight and points `fontFamily` at the matching
/// registered variant, so bold is bold.
///
/// This is also the only place `fontScale` is applied. `buildTheme` must not
/// contain a single `* s.fontScale` — and note that scale multiplies
/// `letterSpacing` too, since Material specifies tracking in logical pixels and
/// leaving it unscaled makes text too tight at 1.30 and too loose at 0.85.
@immutable
class AppTypeTokens {
  const AppTypeTokens._({
    required this.textTheme,
    required this.appBarTitle,
    required this.navLabel,
    required this.dialogTitle,
    required this.tabLabel,
    required this.snackBody,
    required this.kicker,
    required this.numeric,
    required this.numericLarge,
    required this.numericSmall,
  });

  final TextTheme textTheme;

  /// Component-theme styles. These replace the five hand-multiplied
  /// `N * s.fontScale` literals that used to live in `buildTheme`.
  final TextStyle appBarTitle;
  final TextStyle navLabel;
  final TextStyle dialogTitle;
  final TextStyle tabLabel;
  final TextStyle snackBody;

  /// Small uppercase tracked label.
  final TextStyle kicker;

  /// Tabular-figure styles. Money, weights, reps, timers, counts and chart axis
  /// labels all belong here — proportional digits make numbers jitter
  /// horizontally as they change, which is very visible on a live balance.
  final TextStyle numeric;
  final TextStyle numericLarge;
  final TextStyle numericSmall;

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Builds one style. Falls back to Inter, then to the platform font, if the
  /// persisted family name is unknown — `getFont` throws synchronously for an
  /// unregistered family, which a corrupt `theme.font` value could produce.
  static TextStyle _style(
    String? family, {
    required double size,
    required FontWeight weight,
    required double scale,
    double tracking = 0,
    double height = 1.2,
    bool tabular = false,
  }) {
    final features = tabular ? _tabular : null;
    final scaled = size * scale;
    final tracked = tracking * scale;

    if (family == null) {
      return TextStyle(
        fontSize: scaled,
        fontWeight: weight,
        letterSpacing: tracked,
        height: height,
        fontFeatures: features,
      );
    }

    TextStyle resolve(String name) => GoogleFonts.getFont(
      name,
      fontWeight: weight,
      fontSize: scaled,
      letterSpacing: tracked,
      height: height,
    );

    TextStyle base;
    try {
      base = resolve(family);
    } catch (_) {
      try {
        base = resolve(_fallbackFamily);
      } catch (_) {
        return TextStyle(
          fontSize: scaled,
          fontWeight: weight,
          letterSpacing: tracked,
          height: height,
          fontFeatures: features,
        );
      }
    }
    return features == null ? base : base.copyWith(fontFeatures: features);
  }

  static const String _fallbackFamily = 'Inter';

  factory AppTypeTokens.resolve({
    required String family,
    required double scale,
  }) {
    final f = family == 'system' ? null : family;

    TextStyle s(
      double size,
      FontWeight weight, {
      double tr = 0,
      double h = 1.2,
      bool tab = false,
    }) => _style(
      f,
      size: size,
      weight: weight,
      scale: scale,
      tracking: tr,
      height: h,
      tabular: tab,
    );

    return AppTypeTokens._(
      textTheme: TextTheme(
        displayLarge: s(44, FontWeight.w800, tr: -1.0, h: 1.02),
        displayMedium: s(36, FontWeight.w800, tr: -0.8, h: 1.03),
        displaySmall: s(30, FontWeight.w800, tr: -0.6, h: 1.05),
        headlineLarge: s(28, FontWeight.w800, tr: -0.6, h: 1.05),
        headlineMedium: s(24, FontWeight.w800, tr: -0.6, h: 1.06),
        headlineSmall: s(21, FontWeight.w800, tr: -0.5, h: 1.08),
        titleLarge: s(19, FontWeight.w700, tr: -0.3, h: 1.15),
        titleMedium: s(16, FontWeight.w700, tr: -0.1, h: 1.2),
        titleSmall: s(14, FontWeight.w600, h: 1.25),
        bodyLarge: s(16, FontWeight.w400, h: 1.45),
        bodyMedium: s(14, FontWeight.w400, tr: 0.1, h: 1.45),
        bodySmall: s(12.5, FontWeight.w400, tr: 0.15, h: 1.4),
        labelLarge: s(14, FontWeight.w600, tr: 0.1, h: 1.2),
        labelMedium: s(12, FontWeight.w600, tr: 0.4, h: 1.2),
        labelSmall: s(11, FontWeight.w700, tr: 1.4, h: 1.2),
      ),
      appBarTitle: s(20, FontWeight.w700, tr: -0.3),
      navLabel: s(11, FontWeight.w600, tr: 0.1),
      dialogTitle: s(18, FontWeight.w700, tr: -0.2),
      tabLabel: s(13, FontWeight.w600),
      snackBody: s(14, FontWeight.w400, h: 1.35),
      kicker: s(11, FontWeight.w700, tr: 1.4),
      numeric: s(15, FontWeight.w600, tab: true),
      numericLarge: s(32, FontWeight.w800, tr: -1.0, h: 1.02, tab: true),
      numericSmall: s(12.5, FontWeight.w500, tab: true),
    );
  }

  /// Height the bottom navigation bar needs for its resolved label, replacing
  /// the fixed `height: 72` that clipped at large text scales.
  double get navBarHeight => (navLabel.fontSize ?? 11) * 2.4 + 44;
}

/// Weight changes that actually load the right font file.
extension TextStyleWeightX on TextStyle {
  /// Returns this style at [w], re-resolving the Google Fonts family variant.
  ///
  /// `copyWith(fontWeight: ...)` is not enough. Every resolved Google Fonts
  /// style points `fontFamily` at a weight-specific registered family such as
  /// `Inter_400`, which contains only that one face. Asking it for w800 gets a
  /// synthesized smear instead of Inter ExtraBold. This swaps the family
  /// variant along with the weight and leaves size, tracking, height, color and
  /// font features alone.
  ///
  /// Prefer a named role from [AppTypeTokens] where one fits. Reach for this
  /// when a one-off needs emphasis the scale does not name.
  TextStyle weight(FontWeight w) {
    final family = fontFamilyFallback?.isNotEmpty ?? false
        ? fontFamilyFallback!.first
        : null;
    if (family == null) return copyWith(fontWeight: w);
    try {
      final resolved = GoogleFonts.getFont(family, fontWeight: w);
      return copyWith(
        fontFamily: resolved.fontFamily,
        fontFamilyFallback: resolved.fontFamilyFallback,
        fontWeight: w,
      );
    } catch (_) {
      return copyWith(fontWeight: w);
    }
  }
}
