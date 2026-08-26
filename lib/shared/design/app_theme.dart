import 'package:flutter/material.dart';

import 'elevations.dart';
import 'motion.dart';
import 'semantics.dart';
import 'surfaces.dart';
import 'type_tokens.dart';

export 'elevations.dart';
export 'motion.dart';
export 'semantics.dart';
export 'surfaces.dart';
export 'tokens.dart';
export 'type_tokens.dart';

/// The app's design tokens, carried on [ThemeData] as a single extension.
///
/// One composite rather than five separate extensions: the groups are all
/// derived from one [ColorScheme], so splitting them would mean threading the
/// scheme five times — exactly the drift that left `(isDark ? 0.55 : 0.72)`
/// retyped by hand in five different files. It also keeps `copyWith`/`lerp`,
/// which have to be written out by hand, to one implementation instead of five,
/// and costs one extension map lookup per build instead of five.
@immutable
class AppTheme extends ThemeExtension<AppTheme> {
  const AppTheme({
    required this.surfaces,
    required this.motion,
    required this.semantics,
    required this.typography,
  });

  final AppSurfaces surfaces;
  final AppMotion motion;
  final AppSemantics semantics;

  /// Named `typography`, not `type`: [ThemeExtension] already defines a `type`
  /// getter that [ThemeData.extensions] uses as the map key, and shadowing it
  /// would make `Theme.of(context).extension<AppTheme>()` miss.
  final AppTypeTokens typography;

  AppElevations get elevations => surfaces.elevations;

  /// The single construction path, used by `buildTheme` and by the fallback in
  /// [AppThemeX] so a widget pumped outside a themed app renders the same
  /// tokens rather than crashing.
  factory AppTheme.fromScheme(
    ColorScheme cs, {
    required AppTypeTokens typography,
  }) => AppTheme(
    surfaces: AppSurfaces.fromScheme(cs),
    motion: AppMotion.standard,
    semantics: AppSemantics.fromScheme(cs),
    typography: typography,
  );

  @override
  AppTheme copyWith({
    AppSurfaces? surfaces,
    AppMotion? motion,
    AppSemantics? semantics,
    AppTypeTokens? typography,
  }) => AppTheme(
    surfaces: surfaces ?? this.surfaces,
    motion: motion ?? this.motion,
    semantics: semantics ?? this.semantics,
    typography: typography ?? this.typography,
  );

  /// Interpolates anything a human reads as a continuous quantity, and snaps
  /// anything discrete. Lerping [type] would only buy a jittering font size for
  /// one frame, since the family name flips at t=0.5 regardless.
  @override
  AppTheme lerp(ThemeExtension<AppTheme>? other, double t) {
    if (other is! AppTheme) return this;
    return AppTheme(
      surfaces: AppSurfaces.lerp(surfaces, other.surfaces, t),
      semantics: AppSemantics.lerp(semantics, other.semantics, t),
      motion: AppMotion.lerp(motion, other.motion, t),
      typography: t < 0.5 ? typography : other.typography,
    );
  }
}

final Map<ColorScheme, AppTheme> _fallbackCache = <ColorScheme, AppTheme>{};

AppTheme _fallbackFor(ColorScheme cs) {
  if (_fallbackCache.length > 4) {
    return AppTheme.fromScheme(
      cs,
      typography: AppTypeTokens.resolve(family: 'system', scale: 1),
    );
  }
  return _fallbackCache.putIfAbsent(
    cs,
    () => AppTheme.fromScheme(
      cs,
      typography: AppTypeTokens.resolve(family: 'system', scale: 1),
    ),
  );
}

/// Token access.
///
/// Never unwraps the extension with `!`. Widget tests pump screens inside a
/// bare `MaterialApp` with no `buildTheme`, so the extension genuinely can be
/// absent; falling back keeps those trees rendering instead of crashing.
extension AppThemeX on BuildContext {
  AppTheme get app {
    final theme = Theme.of(this);
    return theme.extension<AppTheme>() ?? _fallbackFor(theme.colorScheme);
  }

  AppSurfaces get surfaces => app.surfaces;
  AppSemantics get sem => app.semantics;
  AppTypeTokens get type => app.typography;
  AppElevations get elevation => app.elevations;

  /// Resolves reduced motion here rather than at call sites: [AppMotion.none]
  /// makes every duration zero, and every `Animated*` widget snaps on a zero
  /// duration. Read this in `didChangeDependencies` rather than `build` when
  /// driving an explicit `AnimationController`, since it depends on
  /// `MediaQuery` and so rebuilds on keyboard and rotation changes.
  AppMotion get motion => MediaQuery.maybeDisableAnimationsOf(this) ?? false
      ? AppMotion.none
      : app.motion;
}
