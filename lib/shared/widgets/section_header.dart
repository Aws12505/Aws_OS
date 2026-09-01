import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import 'app_card.dart';

/// The one screen header.
///
/// Set as a masthead: a large tight title, one live line under it, and a rule
/// closing the block. The rule matters more than it looks. It gives every
/// screen the same top edge, so moving between modules feels like turning a
/// page rather than opening a different app.
///
/// The uppercase kicker six screens used to render is gone. It repeated the
/// nav label the reader had just tapped. The line is spent on [status]
/// instead: something true right now, such as today's training state, the
/// month's net, or the count of open tasks.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.status,
    this.statusColor,
    this.statusIcon,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.md,
      AppSpacing.md,
      0,
    ),
    this.rule = false,
  });

  final String title;

  /// One short live line. Say what is true right now, not what the screen is.
  final String? status;

  /// Tints [status] and [statusIcon]. Use the module's semantic colour when the
  /// status carries meaning (behind, on track, overdue), and leave it null when
  /// it is neutral information.
  final Color? statusColor;

  final IconData? statusIcon;

  final Widget? trailing;
  final EdgeInsets padding;

  /// A rule closing the block. Off by default: the cards below carry their own
  /// edges now, and a rule under every masthead as well reads as severe.
  final bool rule;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final surfaces = context.surfaces;
    final statusTone = statusColor ?? surfaces.textTertiary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: padding,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: tt.headlineLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (status != null) ...[
                      const SizedBox(height: AppSpacing.xs + 2),
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
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
        SizedBox(height: status == null ? AppSpacing.md : AppSpacing.sm + 2),
        if (rule) const AppRule(strong: true),
      ],
    );
  }
}

/// The label that opens a group inside a scrolling screen.
///
/// Set in tracked capitals at the smallest size in the scale, with a rule
/// running under it. Caps at 10.5px only work because of the tracking, and the
/// pairing is deliberate: the label is the quietest thing on the page and the
/// rule is what gives it enough presence to divide the content anyway.
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      0,
      AppSpacing.xxl,
      0,
      AppSpacing.sm,
    ),
    this.rule = false,
  });

  final String text;
  final Widget? trailing;
  final EdgeInsets padding;

  /// The rule under the label.
  final bool rule;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  text.toUpperCase(),
                  // Announced in its original casing: a screen reader may spell
                  // an all-caps string out letter by letter.
                  semanticsLabel: text,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: surfaces.textTertiary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (rule) ...[const SizedBox(height: AppSpacing.sm), const AppRule()],
        ],
      ),
    );
  }
}
