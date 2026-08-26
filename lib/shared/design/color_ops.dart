import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Color math used to derive theme tokens from the user's seeded [ColorScheme].
///
/// Everything here runs at theme-build time only — never per frame — so the
/// binary searches below are free in practice as long as `buildTheme` stays
/// memoized (see `app/theme.dart`).

/// WCAG 2.1 relative-contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Memo for [readableOn] and [bestForegroundOn].
///
/// Both run a contrast search, and both are called from `build` — a list of
/// pills would otherwise redo the same twelve-step search on every frame. The
/// inputs are a handful of theme colours, so a small bounded map covers
/// essentially every call.
final Map<(int, int, int), Color> _readableCache = {};

/// Returns [brand] adjusted so it reads at [minContrast] against [on],
/// preserving hue and saturation and moving only lightness.
///
/// Returns [brand] untouched when it already passes. Otherwise it binary-searches
/// lightness and keeps pulling back toward the original, so the result is the
/// *least* altered color that clears the bar — an expense red stays recognizably
/// red instead of washing out toward the surface.
Color readableOn(Color brand, Color on, {double minContrast = 4.5}) {
  final key = (brand.toARGB32(), on.toARGB32(), (minContrast * 100).round());
  final hit = _readableCache[key];
  if (hit != null) return hit;
  final result = _readableOn(brand, on, minContrast);
  if (_readableCache.length > 512) _readableCache.clear();
  return _readableCache[key] = result;
}

Color _readableOn(Color brand, Color on, double minContrast) {
  if (contrastRatio(brand, on) >= minContrast) return brand;

  final hsl = HSLColor.fromColor(brand);
  final lighten = on.computeLuminance() < 0.5; // dark surface -> go lighter
  var lo = lighten ? hsl.lightness : 0.0;
  var hi = lighten ? 1.0 : hsl.lightness;
  var best = hsl.withLightness(lighten ? 1.0 : 0.0).toColor();

  for (var i = 0; i < 12; i++) {
    final mid = (lo + hi) / 2;
    final candidate = hsl.withLightness(mid).toColor();
    if (contrastRatio(candidate, on) >= minContrast) {
      best = candidate;
      if (lighten) {
        hi = mid;
      } else {
        lo = mid;
      }
    } else {
      if (lighten) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
  }
  return best;
}

/// Rotates [c]'s hue a fraction [t] of the way toward [target] along the
/// shortest arc, leaving saturation and lightness alone.
///
/// Used only for the categorical chart palette, so a user's chosen seed tints
/// the charts without touching semantic colors — income green must stay green.
Color nudgeHueToward(Color c, Color target, double t) {
  final a = HSLColor.fromColor(c);
  final b = HSLColor.fromColor(target);
  final delta = ((b.hue - a.hue + 540) % 360) - 180;
  return a.withHue((a.hue + delta * t) % 360).toColor();
}

/// Flattens [c] at [alpha] over [background] into an opaque color.
///
/// Preferred over `withValues(alpha:)` for chip and badge fills: those tints
/// used to stack on a translucent card over a gradient, so the rendered color
/// was unpredictable and contrast could not be guaranteed at all.
Color blendOver(Color c, Color background, double alpha) =>
    Color.alphaBlend(c.withValues(alpha: alpha), background);

/// Picks whichever near-white or near-black reads better on [background].
///
/// The user can choose any seed color, and semantic colors span the spectrum,
/// so neither white nor black is always the right foreground.
Color bestForegroundOn(Color background) {
  const light = Color(0xFFFFFFFF);
  const dark = Color(0xFF11131A);
  final key = (background.toARGB32(), 0, -1);
  final hit = _readableCache[key];
  if (hit != null) return hit;
  final result =
      contrastRatio(light, background) >= contrastRatio(dark, background)
      ? light
      : dark;
  if (_readableCache.length > 512) _readableCache.clear();
  return _readableCache[key] = result;
}
