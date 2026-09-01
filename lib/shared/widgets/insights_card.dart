import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import 'app_card.dart';

/// A chart card: tinted icon, title, optional subtitle and trailing, the chart,
/// then one plain sentence naming the takeaway.
///
/// Promoted from two private `_SectionCard` copies, one in the dashboard
/// insights view and one in the gym's.
///
/// The [takeaway] line is the part that matters. A chart the reader has to
/// interpret unaided is doing half its job, and the analytics services already
/// compute everything these sentences need.
class InsightsCard extends StatelessWidget {
  const InsightsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    required this.color,
    this.subtitle,
    this.trailing,
    this.takeaway,
    this.onTap,
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm - 2,
    ),
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  /// The module's semantic colour.
  final Color color;

  final Widget? trailing;

  /// One sentence saying what the chart shows. Null when there is nothing
  /// honest to say, which is better than padding.
  final String? takeaway;

  final VoidCallback? onTap;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final tt = Theme.of(context).textTheme;

    return AppCard(
      margin: margin,
      onTap: onTap,
      semanticsLabel: onTap == null ? null : 'Open $title',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, color: color, size: 34, iconSize: 17),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: tt.titleMedium),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: tt.bodySmall?.copyWith(
                          color: surfaces.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              ?trailing,
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: surfaces.textTertiary,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
          if (takeaway != null) ...[
            const SizedBox(height: AppSpacing.md),
            // Set on the sunken step so the sentence reads as a caption
            // belonging to the chart rather than as more body copy.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: surfaces.sunken,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                takeaway!,
                style: tt.bodySmall?.copyWith(color: surfaces.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
