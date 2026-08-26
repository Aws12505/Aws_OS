import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/color_ops.dart';

/// Small circular count marker, and the "badge pinned to the corner of a chip"
/// composition that goes with it.
///
/// Promoted from three near-identical private copies in the notes, tasks and
/// finance filter bars, each of which hand-rolled the same
/// `Stack(clipBehavior: Clip.none)` plus `Positioned(top: -2, right: -2)` and
/// its own 9px text style.
class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.count,
    this.color,
    this.semanticsLabel,
  });

  final int count;

  /// Defaults to the theme's tertiary. Pass a module's semantic color to keep
  /// the badge on that module's accent.
  final Color? color;

  /// What a screen reader announces. Without it the badge reads as a bare
  /// number with no indication of what is being counted.
  final String? semanticsLabel;

  /// Wraps [child] and pins the badge to its top-right corner, showing it only
  /// when [count] is greater than zero.
  static Widget overlay({
    required Widget child,
    required int count,
    Color? color,
    String? semanticsLabel,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (count > 0)
          Positioned(
            top: -2,
            right: -2,
            child: CountBadge(
              count: count,
              color: color,
              semanticsLabel: semanticsLabel,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final background = color ?? Theme.of(context).colorScheme.tertiary;
    final label = '$count';
    return Semantics(
      label: semanticsLabel == null ? label : '$label $semanticsLabel',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(3),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Text(
          label,
          style: context.type.numericSmall
              .copyWith(fontSize: 9, color: bestForegroundOn(background))
              .weight(FontWeight.w800),
        ),
      ),
    );
  }
}
