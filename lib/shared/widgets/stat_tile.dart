import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import 'app_card.dart';

/// A headline figure with its label and a tinted icon.
///
/// The icon chip is the point. A row of statistics in one colour is a table;
/// the same row with each figure carrying its domain's colour is scannable
/// without reading, which is what a dashboard is for.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.sub,
    this.onTap,
  });

  final IconData icon;

  /// The module's semantic colour.
  final Color color;

  final String label;
  final String value;
  final String? sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final surfaces = context.surfaces;

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onTap,
      semanticsLabel: onTap == null ? null : '$label, $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(icon: icon, color: color, size: 36, iconSize: 18),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: tt.headlineMedium),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: tt.labelLarge?.copyWith(color: surfaces.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (sub != null)
            Text(
              sub!,
              style: tt.bodySmall?.copyWith(color: surfaces.textTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

/// The compact form of [StatTile], for dense grids.
///
/// Takes a tonal wash of its accent rather than the neutral card fill. Four of
/// these side by side is the one place in the app where colour is doing the
/// most work per pixel: it turns a block of numbers into four distinguishable
/// things.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent,
    this.valueColor,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? accent;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final surfaces = context.surfaces;
    final c = accent ?? cs.primary;
    final role = SemanticRole.derive(c, cs);

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      radius: AppRadius.lg,
      // The container/onContainer pair, not a hand-rolled tint: those two are
      // derived together and contrast-checked against each other, so the label
      // stays readable whatever accent the caller passes.
      fillColor: accent == null ? null : role.container,
      borderColor: accent == null ? null : Colors.transparent,
      onTap: onTap,
      semanticsLabel: onTap == null ? null : '$label, $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: role.onContainer),
                const SizedBox(width: AppSpacing.xs + 1),
              ],
              Expanded(
                child: Text(
                  label,
                  style: tt.labelMedium?.copyWith(
                    color: accent == null
                        ? surfaces.textSecondary
                        : role.onContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: tt.headlineSmall?.copyWith(
                color:
                    valueColor ??
                    (accent == null ? null : role.onContainer),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
