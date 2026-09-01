import 'package:flutter/material.dart';

/// Scheme-tinted shadow presets.
///
/// Opaque surfaces, real depth. This is not the frosted-glass system that was
/// removed: nothing here blurs what is behind it, and nothing is translucent.
/// A card is a solid object that sits slightly above the page, which is what
/// makes a screen feel touchable rather than printed.
///
/// Shadows are tinted toward the scheme's primary rather than pure black. Pure
/// black on a light surface reads as soot; a tinted shadow reads as light
/// falling on a coloured room.
@immutable
class AppElevations {
  const AppElevations({
    required this.flat,
    required this.raised,
    required this.floating,
    required this.overlay,
  });

  /// No shadow. For surfaces that separate by fill alone.
  final List<BoxShadow> flat;

  /// The default card: sitting just above the canvas.
  final List<BoxShadow> raised;

  /// Something detached: a FAB, a hero surface, a selected item.
  final List<BoxShadow> floating;

  /// Sheets, dialogs, menus.
  final List<BoxShadow> overlay;

  factory AppElevations.fromScheme(ColorScheme cs) {
    final dark = cs.brightness == Brightness.dark;
    final tint = Color.lerp(cs.shadow, cs.primary, dark ? 0.22 : 0.28)!;

    /// Two stops per level: a tight contact shadow that anchors the edge, and a
    /// wide soft one that gives it room. One stop alone reads either as a
    /// sticker or as a smudge.
    List<BoxShadow> at(double opacity, double blur, double dy) => [
      BoxShadow(
        color: tint.withValues(alpha: dark ? opacity * 1.6 : opacity * 0.55),
        blurRadius: blur * 0.35,
        offset: Offset(0, dy * 0.3),
      ),
      BoxShadow(
        color: tint.withValues(alpha: dark ? opacity * 2.1 : opacity),
        blurRadius: blur,
        offset: Offset(0, dy),
      ),
    ];

    return AppElevations(
      flat: const [],
      raised: at(0.07, 18, 6),
      floating: at(0.11, 28, 12),
      overlay: at(0.15, 36, 16),
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
