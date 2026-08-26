import 'package:flutter/material.dart';

import '../design/app_theme.dart';

/// A title that flies from a list row to the detail screen it opens.
///
/// Both ends must use the same [tag] and only one of each may be on screen at
/// a time, so tags are scoped by record id.
///
/// Two things this handles that a bare `Hero` does not:
///
/// The flight interpolates the two ends' text styles. Without that the text
/// snaps to the destination style on the first frame and visibly re-lays-out
/// mid-air, which looks worse than no animation at all.
///
/// The child is wrapped in a transparent [Material]. A `Text` lifted out of an
/// `AppBar` into the overlay loses its `Material` ancestor and would otherwise
/// render with debug stripes.
///
/// Note this only works when both ends live in the same `Navigator`. go_router
/// gives the shell and the root their own `HeroControllerScope`, so a row in a
/// tab and a route pushed with `rootNavigator: true` will never pair.
class HeroTitle extends StatelessWidget {
  const HeroTitle({
    super.key,
    required this.tag,
    required this.text,
    required this.style,
    this.maxLines = 1,
  });

  final Object tag;
  final String text;
  final TextStyle style;
  final int maxLines;

  static TextStyle _styleAt(BuildContext heroContext, TextStyle fallback) {
    final hero = heroContext.widget;
    if (hero is Hero) {
      final child = hero.child;
      if (child is _HeroTitleBody) return child.style;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    return Hero(
      tag: tag,
      // Reduced motion: a zero-scale motion token means the app is meant to
      // snap, so drop the shuttle and let the default straight cut happen.
      flightShuttleBuilder: motion.scale == 0
          ? null
          : (flightContext, animation, direction, fromContext, toContext) {
              final from = _styleAt(fromContext, style);
              final to = _styleAt(toContext, style);
              return AnimatedBuilder(
                animation: animation,
                builder: (_, _) => _HeroTitleBody(
                  text: text,
                  style: TextStyle.lerp(from, to, animation.value)!,
                  maxLines: maxLines,
                ),
              );
            },
      child: _HeroTitleBody(text: text, style: style, maxLines: maxLines),
    );
  }
}

class _HeroTitleBody extends StatelessWidget {
  const _HeroTitleBody({
    required this.text,
    required this.style,
    this.maxLines = 1,
  });

  final String text;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
