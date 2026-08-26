import 'package:flutter/material.dart';

/// Scheme-tinted shadow presets.
///
/// Replaces the hand-rolled `BoxShadow`es that were scattered across the app
/// with ad-hoc blur radii (12/22/24/30) and offsets ((0,4)/(0,10)/(0,12)/(0,14)).
/// Shadows are tinted toward the scheme's shadow color rather than pure black,
/// which is what makes them sit on a light surface without looking like soot.
@immutable
class AppElevations {
  const AppElevations({
    required this.flat,
    required this.raised,
    required this.floating,
    required this.overlay,
  });

  /// No shadow. The default for working-mode surfaces, which separate with
  /// hairlines instead of depth.
  final List<BoxShadow> flat;

  /// A card that sits just above the canvas.
  final List<BoxShadow> raised;

  /// Something detached: a FAB, a hero surface, a dragged item.
  final List<BoxShadow> floating;

  /// Sheets, dialogs, menus.
  final List<BoxShadow> overlay;

  factory AppElevations.fromScheme(ColorScheme cs) {
    final dark = cs.brightness == Brightness.dark;
    final tint = Color.lerp(cs.shadow, cs.primary, dark ? 0.10 : 0.16)!;

    List<BoxShadow> at(double opacity, double blur, double dy) => [
      BoxShadow(
        color: tint.withValues(alpha: dark ? opacity * 1.9 : opacity),
        blurRadius: blur,
        offset: Offset(0, dy),
      ),
    ];

    return AppElevations(
      flat: const [],
      raised: at(0.06, 16, 6),
      floating: at(0.10, 24, 10),
      overlay: at(0.14, 32, 14),
    );
  }

  static List<BoxShadow> _lerpList(
    List<BoxShadow> a,
    List<BoxShadow> b,
    double t,
  ) => BoxShadow.lerpList(a, b, t) ?? (t < 0.5 ? a : b);

  static AppElevations lerp(AppElevations a, AppElevations b, double t) =>
      AppElevations(
        flat: const [],
        raised: _lerpList(a.raised, b.raised, t),
        floating: _lerpList(a.floating, b.floating, t),
        overlay: _lerpList(a.overlay, b.overlay, t),
      );
}
