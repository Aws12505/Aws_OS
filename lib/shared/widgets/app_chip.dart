import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/color_ops.dart';

/// Interactive pill for filters, tags and choices.
///
/// Selected means filled with the accent, not tinted at 18% behind a 50%
/// border. A tint plus a translucent outline is two weak signals; one solid
/// fill is unambiguous at a glance, which is what a filter row needs.
///
/// For read-only inline metadata use `MiniPill`; this is its tappable sibling.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final surfaces = context.surfaces;
    final c = color ?? cs.primary;

    // Any seed is possible and the caller can pass a palette colour, so ask
    // which extreme actually passes on this fill rather than assuming white.
    final fg = selected ? bestForegroundOn(c) : surfaces.textSecondary;
    final radius = BorderRadius.circular(AppRadius.pill);

    return Material(
      color: selected ? c : Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm - 1,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? c : surfaces.hairlineStrong,
              width: AppSurfaces.hairlineWidth,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: AppSpacing.xs + 2),
              ],
              Text(
                label,
                style: tt.labelMedium
                    ?.copyWith(color: fg)
                    .weight(selected ? FontWeight.w700 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
