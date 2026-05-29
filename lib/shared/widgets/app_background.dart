import 'package:flutter/material.dart';

/// Ambient "aurora" backdrop: soft radial-gradient orbs bleeding in from the
/// edges over a base surface. Pure gradients — no runtime blur — so it stays
/// cheap to paint behind scrolling content. Drop it at the bottom of a Stack
/// and render screen content above it on transparent scaffolds.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({
    super.key,
    this.child,
    this.accent,
  });

  final Widget? child;

  /// Optional accent that tints the primary orb — used by per-workspace or
  /// per-section theming to make a screen feel bespoke.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = accent ?? cs.primary;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [cs.surface, cs.surfaceContainerLowest]
                  : [cs.surface, cs.surfaceContainerLow],
            ),
          ),
        ),
        Positioned(
          top: -180,
          right: -130,
          child: _Orb(
            color: primary,
            size: 420,
            opacity: isDark ? 0.32 : 0.24,
          ),
        ),
        Positioned(
          top: 140,
          left: -160,
          child: _Orb(
            color: cs.secondary,
            size: 360,
            opacity: isDark ? 0.26 : 0.20,
          ),
        ),
        Positioned(
          bottom: -200,
          right: -80,
          child: _Orb(
            color: cs.tertiary,
            size: 400,
            opacity: isDark ? 0.24 : 0.18,
          ),
        ),
        ?child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.color,
    required this.size,
    required this.opacity,
  });
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
