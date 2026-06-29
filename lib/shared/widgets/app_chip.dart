import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// Interactive pill/chip for filters, tags and choices.
///
/// For read-only inline metadata (counts, dates) use `MiniPill` from glass.dart;
/// this is its tappable, selectable sibling.
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
    final c = color ?? cs.primary;
    final bg = selected
        ? c.withValues(alpha: 0.18)
        : cs.surface.withValues(alpha: 0.5);
    final fg = selected ? c : cs.onSurfaceVariant;
    final border = selected
        ? c.withValues(alpha: 0.5)
        : cs.outlineVariant.withValues(alpha: 0.5);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: tt.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
