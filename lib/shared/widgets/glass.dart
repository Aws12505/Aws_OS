import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted translucent surface that lets the aurora bleed through. By default
/// it uses a translucent fill + hairline border (cheap, list-safe). Set
/// [blur] true for fixed/hero surfaces where a real backdrop blur is worth it.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    this.radius = 22,
    this.onTap,
    this.blur = false,
    this.fillOpacity,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double radius;
  final VoidCallback? onTap;
  final bool blur;
  final double? fillOpacity;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = cs.surface.withValues(
      alpha: fillOpacity ?? (isDark ? 0.55 : 0.72),
    );
    final border = borderColor ??
        (isDark
            ? cs.onSurface.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.55));

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    if (blur) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: content,
        ),
      );
    }

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: content),
      );
    }

    return Padding(padding: margin, child: content);
  }
}

/// Editorial section label: a small kicker + a large display title, used to
/// give screens a magazine-like hierarchy.
class EditorialHeader extends StatelessWidget {
  const EditorialHeader({
    super.key,
    required this.kicker,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 16, 4),
  });

  final String kicker;
  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kicker.toUpperCase(),
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small pill used for inline metadata (tags, counts, dates).
class MiniPill extends StatelessWidget {
  const MiniPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
  });

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: c,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
