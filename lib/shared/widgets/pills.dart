import 'package:flutter/material.dart';

import '../design/app_theme.dart';

/// Small pill for inline metadata: tags, counts, dates.
///
/// Takes a tonal wash of its semantic colour, pre-blended against the surface
/// rather than laid over it at an alpha, so the label's contrast is guaranteed
/// instead of depending on whatever is behind the card.
class MiniPill extends StatelessWidget {
  const MiniPill({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;

  /// A semantic colour. Defaults to the theme primary.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final role = SemanticRole.derive(color ?? cs.primary, cs);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: role.container,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: role.onContainer),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: tt.labelMedium?.copyWith(color: role.onContainer),
          ),
        ],
      ),
    );
  }
}
