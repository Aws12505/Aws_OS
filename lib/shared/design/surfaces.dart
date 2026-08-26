import 'package:flutter/material.dart';

import 'elevations.dart';

/// How prominent a surface is relative to its siblings inside the same screen.
enum SurfaceTone {
  /// The default card.
  base,

  /// One step up: a hero tile, a selected row, a nested emphasis.
  raised,

  /// One step down: an inset well, a chart backdrop, a disabled area.
  sunken,
}

/// A resolved surface: what to fill with, what to outline with, how much to
/// blur behind it, and how it casts.
@immutable
class SurfaceSpec {
  const SurfaceSpec({
    required this.fill,
    required this.border,
    required this.shadow,
    this.blurSigma,
  });

  final Color fill;
  final Color border;
  final List<BoxShadow> shadow;

  /// Non-null only for ambient glass surfaces that earn a real backdrop blur.
  final double? blurSigma;
}

/// Surface, border and text-emphasis tokens.
///
/// Two things live here that the app previously retyped by hand in five files:
/// the glass fill alpha pair `(isDark ? 0.55 : 0.72)`, and the hairline alpha
/// that drifted between 0.35, 0.40, 0.45 and 0.50 depending on the file.
@immutable
class AppSurfaces {
  const AppSurfaces({
    required this.canvas,
    required this.raised,
    required this.sunken,
    required this.overlay,
    required this.hairline,
    required this.hairlineStrong,
    required this.glassFill,
    required this.glassBorder,
    required this.navFill,
    required this.navBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textQuaternary,
    required this.elevations,
    required this.glassBlurSigma,
  });

  /// Opaque page background for working-mode screens. Painting this is what
  /// hides the global aurora without unmounting it, and it is also what stops
  /// the outgoing screen showing through during a push.
  final Color canvas;
  final Color raised;
  final Color sunken;
  final Color overlay;

  /// The default 1px separator. Use between list rows, not around them.
  final Color hairline;
  final Color hairlineStrong;

  final Color glassFill;
  final Color glassBorder;
  final Color navFill;
  final Color navBorder;

  /// Four-level text emphasis ramp. The rule:
  ///   primary    — the thing you are reading (titles, values, body)
  ///   secondary  — supporting copy, labels, units, subtitles
  ///   tertiary   — metadata, timestamps, inactive states, placeholders
  ///   quaternary — dividers-as-text, disabled glyphs, decorative marks
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textQuaternary;

  final AppElevations elevations;
  final double glassBlurSigma;

  factory AppSurfaces.fromScheme(ColorScheme cs) {
    final dark = cs.brightness == Brightness.dark;
    final on = cs.onSurface;

    return AppSurfaces(
      canvas: dark ? cs.surface : cs.surfaceContainerLowest,
      raised: cs.surfaceContainerLow,
      sunken: cs.surfaceContainerHighest,
      overlay: cs.surfaceContainerHigh,
      hairline: cs.outlineVariant.withValues(alpha: dark ? 0.34 : 0.44),
      hairlineStrong: cs.outlineVariant.withValues(alpha: dark ? 0.55 : 0.70),
      glassFill: cs.surface.withValues(alpha: dark ? 0.55 : 0.72),
      glassBorder: dark
          ? on.withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.55),
      navFill: cs.surface.withValues(alpha: dark ? 0.60 : 0.78),
      navBorder: cs.outlineVariant.withValues(alpha: 0.40),
      textPrimary: on,
      textSecondary: on.withValues(alpha: dark ? 0.66 : 0.62),
      textTertiary: on.withValues(alpha: dark ? 0.42 : 0.40),
      textQuaternary: on.withValues(alpha: dark ? 0.24 : 0.22),
      elevations: AppElevations.fromScheme(cs),
      glassBlurSigma: 18,
    );
  }

  /// Frosted translucent surface for ambient screens.
  SurfaceSpec glass(SurfaceTone tone, {bool blur = false}) {
    final fill = switch (tone) {
      SurfaceTone.base => glassFill,
      SurfaceTone.raised => Color.alphaBlend(
        textPrimary.withValues(alpha: 0.04),
        glassFill,
      ),
      SurfaceTone.sunken => glassFill.withValues(
        alpha: (glassFill.a * 0.72).clamp(0.0, 1.0),
      ),
    };
    return SurfaceSpec(
      fill: fill,
      border: glassBorder,
      shadow: tone == SurfaceTone.sunken ? elevations.flat : elevations.raised,
      blurSigma: blur ? glassBlurSigma : null,
    );
  }

  /// Opaque layered surface for working screens. No blur, no stacked shadows —
  /// separation comes from the layer step and the hairline.
  SurfaceSpec flat(SurfaceTone tone) => SurfaceSpec(
    fill: switch (tone) {
      SurfaceTone.base => raised,
      SurfaceTone.raised => overlay,
      SurfaceTone.sunken => sunken,
    },
    border: hairline,
    shadow: elevations.flat,
  );

  static AppSurfaces lerp(AppSurfaces a, AppSurfaces b, double t) =>
      AppSurfaces(
        canvas: Color.lerp(a.canvas, b.canvas, t)!,
        raised: Color.lerp(a.raised, b.raised, t)!,
        sunken: Color.lerp(a.sunken, b.sunken, t)!,
        overlay: Color.lerp(a.overlay, b.overlay, t)!,
        hairline: Color.lerp(a.hairline, b.hairline, t)!,
        hairlineStrong: Color.lerp(a.hairlineStrong, b.hairlineStrong, t)!,
        glassFill: Color.lerp(a.glassFill, b.glassFill, t)!,
        glassBorder: Color.lerp(a.glassBorder, b.glassBorder, t)!,
        navFill: Color.lerp(a.navFill, b.navFill, t)!,
        navBorder: Color.lerp(a.navBorder, b.navBorder, t)!,
        textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t)!,
        textSecondary: Color.lerp(a.textSecondary, b.textSecondary, t)!,
        textTertiary: Color.lerp(a.textTertiary, b.textTertiary, t)!,
        textQuaternary: Color.lerp(a.textQuaternary, b.textQuaternary, t)!,
        elevations: AppElevations.lerp(a.elevations, b.elevations, t),
        glassBlurSigma: t < 0.5 ? a.glassBlurSigma : b.glassBlurSigma,
      );
}
