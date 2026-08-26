import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import 'app_chip.dart';
import 'count_badge.dart';

/// The filter row that sits under a screen's search field.
///
/// Promoted from three private `_FilterBar` copies in notes, tasks and finance.
/// They agreed on the idea and disagreed on everything else: which chip carried
/// the count, whether Clear appeared, and how much padding sat above it.
class AppFilterBar extends StatelessWidget {
  const AppFilterBar({
    super.key,
    required this.activeCount,
    required this.color,
    required this.onOpenFilters,
    this.onClear,
    this.leading = const [],
    this.trailing = const [],
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      6,
      AppSpacing.lg,
      6,
    ),
  });

  /// How many filter dimensions are set. Drives both the selected state and the
  /// badge, so the chip cannot look active while the badge says zero.
  final int activeCount;

  /// The module's semantic colour.
  final Color color;

  final VoidCallback onOpenFilters;

  /// Shown as a Clear chip when non-null. Pass null when the filter is already
  /// at its default, so the row does not offer an action that does nothing.
  final VoidCallback? onClear;

  final List<Widget> leading;
  final List<Widget> trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          ...leading,
          if (leading.isNotEmpty) const SizedBox(width: AppSpacing.sm),
          CountBadge.overlay(
            count: activeCount,
            color: color,
            semanticsLabel: activeCount == 1
                ? 'filter active'
                : 'filters active',
            child: AppChip(
              label: 'Filters',
              icon: Icons.tune_rounded,
              color: color,
              selected: activeCount > 0,
              onTap: onOpenFilters,
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(width: AppSpacing.sm),
            AppChip(
              label: 'Clear',
              icon: Icons.close_rounded,
              color: cs.error,
              onTap: onClear,
            ),
          ],
          ...trailing,
        ],
      ),
    );
  }
}
