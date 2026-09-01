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

/// A resolved surface: what to fill with, what to outline with, how it casts.
@immutable
class SurfaceSpec {
  const SurfaceSpec({
    required this.fill,
    required this.border,
    this.shadow = const <BoxShadow>[],
  });

  final Color fill;
  final Color border;
  final List<BoxShadow> shadow;
}

/// Surface, rule and text-emphasis tokens.
///
/// The canvas carries a real trace of the user's seed rather than sitting on
/// the neutral axis. A page that is exactly grey makes every coloured thing on
/// it look pasted on; a page tinted a few percent toward the accent makes the
/// same colours look like they belong to the same room.
@immutable
class AppSurfaces {
  const AppSurfaces({
    required this.canvas,
    required this.raised,
    required this.sunken,
    required this.overlay,
    required this.hairline,
    required this.hairlineStrong,
    required this.navFill,
    required this.navBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textQuaternary,
    required this.elevations,
    required this.tintStrength,
  });

  /// Page background.
  final Color canvas;

  /// The default card fill: one clear step off the canvas.
  final Color raised;

  /// An inset well: a chart backdrop, a progress track, a read-only field.
  final Color sunken;

  /// Sheets, dialogs and menus, which sit above the page rather than on it.
  final Color overlay;

  /// The one-pixel rule, for dividing rows inside a surface.
  final Color hairline;

  /// A rule that terminates a section rather than dividing one.
  final Color hairlineStrong;

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

  /// How much of a semantic colour a tonal container takes. Higher in dark,
  /// where a tint has to work against a much darker ground to register.
  final double tintStrength;

  /// Rule thickness. One value, everywhere.
  static const double hairlineWidth = 1;

  /// Builds a surface at a fixed lightness, keeping a bounded amount of the
  /// seed's hue so the greys belong to the same palette as the accent.
  static Color _shade(ColorScheme cs, double lightness, double saturation) {
    final hsl = HSLColor.fromColor(cs.primary);
    return hsl.withSaturation(saturation).withLightness(lightness).toColor();
  }

  factory AppSurfaces.fromScheme(ColorScheme cs) {
    final dark = cs.brightness == Brightness.dark;
    final on = cs.onSurface;

    return AppSurfaces(
      canvas: dark ? _shade(cs, 0.062, 0.14) : _shade(cs, 0.975, 0.30),
      raised: dark ? _shade(cs, 0.115, 0.13) : _shade(cs, 1.0, 0.0),
      sunken: dark ? _shade(cs, 0.165, 0.12) : _shade(cs, 0.935, 0.26),
      overlay: dark ? _shade(cs, 0.135, 0.13) : _shade(cs, 1.0, 0.0),
      hairline: on.withValues(alpha: dark ? 0.10 : 0.08),
      hairlineStrong: on.withValues(alpha: dark ? 0.20 : 0.15),
      navFill: dark ? _shade(cs, 0.095, 0.14) : _shade(cs, 1.0, 0.0),
      navBorder: on.withValues(alpha: dark ? 0.10 : 0.07),
      textPrimary: on,
      textSecondary: on.withValues(alpha: dark ? 0.68 : 0.64),
      textTertiary: on.withValues(alpha: dark ? 0.45 : 0.42),
      textQuaternary: on.withValues(alpha: dark ? 0.26 : 0.24),
      elevations: AppElevations.fromScheme(cs),
      tintStrength: dark ? 0.22 : 0.14,
    );
  }

  /// A tonal container in [color]: the fill for an icon chip, a badge, a
  /// highlighted row.
  ///
  /// Pre-blended against the surface it will sit on rather than laid over it at
  /// an alpha, so the colour that ends up on screen is the colour whose
  /// contrast was checked.
  Color tint(Color color, {double? strength, Color? over}) => Color.alphaBlend(
    color.withValues(alpha: strength ?? tintStrength),
    over ?? raised,
  );

  /// The default card: filled, rounded, and lifted off the page.
  SurfaceSpec block(SurfaceTone tone) => SurfaceSpec(
    fill: switch (tone) {
      SurfaceTone.base => raised,
      SurfaceTone.raised => overlay,
      SurfaceTone.sunken => sunken,
    },
    border: tone == SurfaceTone.sunken ? Colors.transparent : hairline,
    shadow: switch (tone) {
      SurfaceTone.base => elevations.raised,
      SurfaceTone.raised => elevations.floating,
      SurfaceTone.sunken => elevations.flat,
    },
  );

  /// No fill and no border, for content that sits directly on the canvas.
  SurfaceSpec get plain =>
      const SurfaceSpec(fill: Colors.transparent, border: Colors.transparent);

  static AppSurfaces lerp(AppSurfaces a, AppSurfaces b, double t) =>
      AppSurfaces(
        canvas: Color.lerp(a.canvas, b.canvas, t)!,
        raised: Color.lerp(a.raised, b.raised, t)!,
        sunken: Color.lerp(a.sunken, b.sunken, t)!,
        overlay: Color.lerp(a.overlay, b.overlay, t)!,
        hairline: Color.lerp(a.hairline, b.hairline, t)!,
        hairlineStrong: Color.lerp(a.hairlineStrong, b.hairlineStrong, t)!,
        navFill: Color.lerp(a.navFill, b.navFill, t)!,
        navBorder: Color.lerp(a.navBorder, b.navBorder, t)!,
        textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t)!,
        textSecondary: Color.lerp(a.textSecondary, b.textSecondary, t)!,
        textTertiary: Color.lerp(a.textTertiary, b.textTertiary, t)!,
        textQuaternary: Color.lerp(a.textQuaternary, b.textQuaternary, t)!,
        elevations: AppElevations.lerp(a.elevations, b.elevations, t),
        tintStrength: a.tintStrength + (b.tintStrength - a.tintStrength) * t,
      );
}
