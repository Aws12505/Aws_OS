import 'package:flutter/material.dart';

/// Duration and easing tokens.
///
/// Collapses the six ad-hoc durations the app used to carry (180/200/220/240/
/// 280/420) onto a scale, and gives the three `AnimatedContainer`s that
/// silently fell back to `Curves.linear` a real curve.
///
/// Discipline, borrowed from openGym's two-duration system: [quick] and [short]
/// should cover almost everything. Reaching for [medium] or [long] needs a
/// reason you can say in one sentence.
///
/// Reduced motion is handled by [none], whose [scale] of 0 turns every duration
/// into [Duration.zero]. `AnimatedContainer`, `AnimatedOpacity`,
/// `AnimatedSwitcher` and `AnimationController` all snap on a zero duration, so
/// no widget in the app needs an `if (reduceMotion)` branch.
@immutable
class AppMotion {
  const AppMotion._({required this.scale});

  /// 1.0 normally, 0.0 when the platform asks for reduced motion.
  final double scale;

  static const AppMotion standard = AppMotion._(scale: 1);
  static const AppMotion none = AppMotion._(scale: 0);

  Duration _d(int ms) => Duration(milliseconds: (ms * scale).round());

  /// Press feedback, ripples, instant acknowledgements.
  Duration get instant => _d(50);

  /// Checkbox ticks, chip selection, small toggles. The workhorse.
  Duration get quick => _d(100);

  /// Row expansion, small surface changes, segmented indicator. The workhorse.
  Duration get short => _d(200);

  /// Cards, sheets, list reorders.
  Duration get medium => _d(350);

  /// Full-screen transitions and hero flights.
  Duration get long => _d(500);

  Curve get standardCurve => Easing.standard;

  /// Something appearing. Decelerates into place.
  Curve get enter => Easing.emphasizedDecelerate;

  /// Something leaving. Accelerates away, and should be shorter than its enter.
  Curve get exit => Easing.emphasizedAccelerate;

  /// Large, expressive motion: hero flights, sheet presentation.
  Curve get emphasized => Curves.easeInOutCubicEmphasized;

  /// Scale applied to a tappable surface while pressed. openGym uses .975 on
  /// every control; the same value reads right at this density.
  double get pressScale => scale == 0 ? 1.0 : 0.975;

  static AppMotion lerp(AppMotion a, AppMotion b, double t) => t < 0.5 ? a : b;
}
