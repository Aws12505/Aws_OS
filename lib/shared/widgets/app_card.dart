import 'dart:ui';

import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/surface_scope.dart';

/// Resolves the surface treatment for the current scope.
///
/// Anything that paints its own container rather than using [AppCard] should
/// go through this, so it flips between frosted and flat with everything else
/// instead of hard-coding the glass alpha pair.
SurfaceSpec resolveSurface(
  BuildContext context, {
  SurfaceTone tone = SurfaceTone.base,
  SurfaceVariant variant = SurfaceVariant.auto,
  bool blur = false,
}) {
  final mode = switch (variant) {
    SurfaceVariant.glass => SurfaceMode.ambient,
    SurfaceVariant.flat => SurfaceMode.working,
    SurfaceVariant.auto => SurfaceScope.of(context),
  };
  final surfaces = context.surfaces;
  return mode == SurfaceMode.ambient
      ? surfaces.glass(tone, blur: blur)
      : surfaces.flat(tone);
}

/// The app's one card.
///
/// Renders frosted-translucent on ambient screens and flat-opaque on working
/// screens, resolved from the enclosing [SurfaceScope]. That is what lets a
/// dense list or the workout screen stay legible while the dashboard keeps the
/// aurora showing through, without forking into two component sets.
///
/// Pass [variant] explicitly inside anything that escapes the scope — modal
/// sheets and dialogs go through the root navigator, so they are not
/// descendants of a screen's [SurfaceScope].
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: 7,
    ),
    this.radius = AppRadius.xxl,
    this.onTap,
    this.variant = SurfaceVariant.auto,
    this.tone = SurfaceTone.base,
    this.blur = false,
    this.borderColor,
    this.fillColor,
    this.semanticsLabel,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double radius;
  final VoidCallback? onTap;

  /// Defaults to reading the ambient [SurfaceScope].
  final SurfaceVariant variant;

  /// Prominence relative to siblings on the same screen.
  final SurfaceTone tone;

  /// Real backdrop blur. Only meaningful in the glass variant, and only worth
  /// it on fixed or hero surfaces: it is a per-frame cost, so it stays off in
  /// scrolling lists.
  final bool blur;

  final Color? borderColor;
  final Color? fillColor;

  /// Set when the card is tappable and its contents do not already say where
  /// the tap goes.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final spec = resolveSurface(
      context,
      tone: tone,
      variant: variant,
      blur: blur,
    );

    final borderRadius = BorderRadius.circular(radius);

    Widget content = AnimatedContainer(
      duration: motion.short,
      curve: motion.standardCurve,
      padding: padding,
      decoration: BoxDecoration(
        color: fillColor ?? spec.fill,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? spec.border, width: 1),
        boxShadow: spec.shadow,
      ),
      child: child,
    );

    if (spec.blurSigma != null) {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: spec.blurSigma!,
            sigmaY: spec.blurSigma!,
          ),
          child: content,
        ),
      );
    }

    if (onTap != null) {
      content = PressableSurface(
        onTap: onTap!,
        borderRadius: borderRadius,
        semanticsLabel: semanticsLabel,
        child: content,
      );
    }

    return Padding(padding: margin, child: content);
  }
}

/// Tap target with press feedback for surfaces Material does not give a ripple.
///
/// The app is full of hand-rolled `Container` + `GestureDetector` cards that
/// acknowledged a tap with nothing at all. This adds the ripple plus a small
/// scale-down, which is the feedback openGym gives every control, and it
/// collapses to nothing under reduced motion because the scale comes from the
/// motion tokens.
class PressableSurface extends StatefulWidget {
  const PressableSurface({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius,
    this.onLongPress,
    this.semanticsLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final String? semanticsLabel;

  @override
  State<PressableSurface> createState() => _PressableSurfaceState();
}

class _PressableSurfaceState extends State<PressableSurface> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final radius = widget.borderRadius ?? BorderRadius.circular(AppRadius.lg);

    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      child: AnimatedScale(
        scale: _pressed ? motion.pressScale : 1.0,
        duration: motion.instant,
        curve: motion.standardCurve,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
