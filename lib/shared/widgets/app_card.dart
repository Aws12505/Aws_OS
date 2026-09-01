import 'package:flutter/material.dart';

import '../design/app_theme.dart';

/// How a surface separates itself from the page.
enum CardStyle {
  /// Filled, rounded and lifted off the canvas. The default: most things a
  /// screen shows are objects you could pick up, and a surface that casts a
  /// little shadow reads that way where a flat rectangle does not.
  block,

  /// A rule across the top and nothing else: no fill, no shadow, flush to the
  /// page margin. For a genuine section of a page rather than an object on it,
  /// where a box would just be a border round content the heading already
  /// names.
  section,

  /// Nothing at all, not even the rule.
  plain,

  /// An inset well, a step *into* the page. Chart backdrops, read-only values.
  well,
}

/// Resolves the fill, rule and shadow for a surface painted by hand.
///
/// Anything drawing its own container rather than using [AppCard] should go
/// through this so it picks up the tokens instead of hard-coding a fill.
SurfaceSpec resolveSurface(
  BuildContext context, {
  SurfaceTone tone = SurfaceTone.base,
}) => context.surfaces.block(tone);

/// The app's one card.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = AppRadius.xl,
    this.onTap,
    this.style = CardStyle.block,
    this.tone = SurfaceTone.base,
    this.borderColor,
    this.fillColor,
    this.semanticsLabel,
  });

  /// A section with no rule of its own.
  const AppCard.plain({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.tone = SurfaceTone.base,
    this.semanticsLabel,
  }) : style = CardStyle.plain,
       radius = AppRadius.md,
       borderColor = null,
       fillColor = null;

  final Widget child;

  /// Defaults per style: a box pads on all four sides, a section only needs
  /// vertical padding because its margin already sets the text column.
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  final double radius;
  final VoidCallback? onTap;
  final CardStyle style;

  /// Prominence relative to siblings on the same screen.
  final SurfaceTone tone;

  final Color? borderColor;
  final Color? fillColor;

  /// Set when the card is tappable and its contents do not already say where
  /// the tap goes.
  final String? semanticsLabel;

  bool get _boxed => style == CardStyle.block || style == CardStyle.well;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final surfaces = context.surfaces;

    final spec = switch (style) {
      CardStyle.block => surfaces.block(tone),
      CardStyle.well => surfaces.block(SurfaceTone.sunken),
      CardStyle.section || CardStyle.plain => surfaces.plain,
    };

    final effectivePadding =
        padding ??
        (_boxed
            ? const EdgeInsets.all(AppSpacing.lg + 2)
            : const EdgeInsets.symmetric(vertical: AppSpacing.lg));
    final effectiveMargin =
        margin ??
        (_boxed
            ? const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs + 2,
              )
            : const EdgeInsets.symmetric(horizontal: AppSpacing.xl));

    final borderRadius = BorderRadius.circular(radius);
    final border = borderColor ?? spec.border;

    Widget content = AnimatedContainer(
      duration: motion.short,
      curve: motion.standardCurve,
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: fillColor ?? spec.fill,
        borderRadius: _boxed ? borderRadius : null,
        border: border == Colors.transparent
            ? null
            : Border.all(color: border, width: AppSurfaces.hairlineWidth),
        boxShadow: spec.shadow,
      ),
      child: child,
    );

    if (style == CardStyle.section) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [const AppRule(strong: true), content],
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

    return Padding(padding: effectiveMargin, child: content);
  }
}

/// A round-cornered chip holding an icon, filled with a tonal wash of [color].
///
/// The app is full of these — one per card header, one per list row kind, one
/// per quick action — and they were the single biggest thing lost when the
/// design went monochrome. An icon in a tinted container is what tells you at a
/// glance whether a row is money in or money out, without reading it.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize,
    this.radius = AppRadius.md,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final role = SemanticRole.derive(color, Theme.of(context).colorScheme);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: role.container,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: role.onContainer, size: iconSize ?? size * 0.48),
    );
  }
}

/// The one-pixel rule.
///
/// Use it *between* things. A rule above the first row and below the last one
/// turns a list back into a box, which is what this design is replacing.
class AppRule extends StatelessWidget {
  const AppRule({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
    this.strong = false,
  });

  /// Inset from the leading edge. Align to where the row's text starts, so the
  /// rule reads as belonging to the column rather than cutting across it.
  final double indent;
  final double endIndent;

  /// A rule that ends a section rather than dividing one.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Padding(
      padding: EdgeInsets.only(left: indent, right: endIndent),
      child: SizedBox(
        height: AppSurfaces.hairlineWidth,
        child: ColoredBox(
          color: strong ? surfaces.hairlineStrong : surfaces.hairline,
        ),
      ),
    );
  }
}

/// Rows separated by rules instead of boxed one by one.
///
/// This is the shape dense content wants: transactions, tasks, exercises,
/// accounts, received files. One region, many rows, a hairline between each.
/// Boxing each row costs a border, a radius and a gap per item and buys
/// nothing, and at list length it is the single biggest reason a screen reads
/// as cluttered.
class RuledColumn extends StatelessWidget {
  const RuledColumn({
    super.key,
    required this.children,
    this.indent = AppSpacing.xl,
    this.endIndent = AppSpacing.xl,
  });

  final List<Widget> children;
  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) AppRule(indent: indent, endIndent: endIndent),
          children[i],
        ],
      ],
    );
  }
}

/// Tap target with press feedback for surfaces Material does not give a ripple.
///
/// The app is full of hand-rolled `Container` + `GestureDetector` cards that
/// acknowledged a tap with nothing at all. This adds the ripple plus a small
/// scale-down, and it collapses to nothing under reduced motion because the
/// scale comes from the motion tokens.
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
