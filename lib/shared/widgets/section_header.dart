import 'package:flutter/material.dart';

import '../design/app_theme.dart';

/// The one screen header.
///
/// Replaces six inline copies of the same kicker-plus-title column, each with
/// byte-identical `fromLTRB(20, 14, 12, 6)` padding.
///
/// The uppercase kicker those copies rendered is gone on purpose. It repeated
/// the bottom-nav label the user had just tapped, and six identical eyebrows
/// across six screens read as a template. The line is spent on [status]
/// instead: something live and specific to this screen, such as today's
/// training state, the month's net, or the count of open tasks.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.status,
    this.statusColor,
    this.statusIcon,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 12, 8),
  });

  final String title;

  /// One short live line. Say what is true right now, not what the screen is.
  final String? status;

  /// Tints [status] and [statusIcon]. Use the module's semantic color when the
  /// status carries meaning (behind, on track, overdue), and leave it null when
  /// it is neutral information.
  final Color? statusColor;

  final IconData? statusIcon;

  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final surfaces = context.surfaces;
    final statusTone = statusColor ?? surfaces.textSecondary;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: tt.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (status != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (statusIcon != null) ...[
                        Icon(statusIcon, size: 13, color: statusTone),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(
                          status!,
                          style: tt.bodySmall?.copyWith(color: statusTone),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
        ],
      ),
    );
  }
}

/// Small label that separates groups inside a scrolling screen.
///
/// Promoted from three private copies (`_SectionLabel` in the measurements,
/// task-filter and note-filter files) that each picked their own tracking and
/// their own grey.
///
/// Sentence case, not uppercase: an all-caps label above every group is the
/// same templated rhythm the screen headers were carrying, and it competes with
/// the content for attention.
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(4, AppSpacing.lg, 4, AppSpacing.sm),
  });

  final String text;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
