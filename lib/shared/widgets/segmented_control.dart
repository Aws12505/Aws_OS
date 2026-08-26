import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/app_theme.dart';
import '../design/color_ops.dart';
import 'app_card.dart';

/// A pill-style segmented control — the app's house alternative to a raw
/// [TabBar]. The selected segment gets a filled primary background with a soft
/// glow; the rest stay flat. Promoted from finance_screen so the dashboard,
/// finance and any future screens share one implementation.
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.labels,
    required this.index,
    required this.onTap,
    this.icons,
    this.color,
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: 6,
    ),
  });

  final List<String> labels;

  /// Optional leading icon per segment. When null (or shorter than [labels]),
  /// the affected segments render label-only.
  final List<IconData>? icons;

  /// Selected-segment fill. Defaults to the theme primary; pass a feature accent
  /// (e.g. the gym red) to tint the control.
  final Color? color;
  final int index;
  final ValueChanged<int> onTap;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final selectedBg = color ?? cs.primary;
    // White is not always readable on a caller-supplied accent, and the user
    // can pick any seed. Ask which of the two extremes actually passes.
    final selectedFg = color != null
        ? bestForegroundOn(selectedBg)
        : cs.onPrimary;
    final surface = resolveSurface(context);
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surface.fill,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: surface.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (i == index) return;
                  HapticFeedback.selectionClick();
                  onTap(i);
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: context.motion.short,
                  curve: context.motion.standardCurve,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == index ? selectedBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: i == index
                        ? [
                            BoxShadow(
                              color: selectedBg.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  // Scale the icon+label down to fit narrow segments (many
                  // tabs / long labels) instead of truncating the text.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icons != null && i < icons!.length) ...[
                          Icon(
                            icons![i],
                            size: 16,
                            color:
                                i == index ? selectedFg : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          labels[i],
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: tt.labelLarge?.copyWith(
                            color: i == index
                                ? selectedFg
                                : cs.onSurfaceVariant,
                          ).weight(FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
