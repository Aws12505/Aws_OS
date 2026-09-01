import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/app_theme.dart';

/// Underlined tabs. The app's one segmented control.
///
/// It used to be a pill: a bordered track with a filled, glowing capsule
/// sliding between segments. That is three decorations to say one thing. A rule
/// under the row and a heavier rule under the selected label says it with two
/// lines, and it matches the rules everything else on the page is separated by.
///
/// The selected marker animates its width and offset, which is the one place
/// in this design where motion carries meaning rather than polish: it shows
/// which way you moved.
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.labels,
    required this.index,
    required this.onTap,
    this.icons,
    this.color,
    this.margin = const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
  });

  final List<String> labels;

  /// Optional leading icon per segment. When null (or shorter than [labels]),
  /// the affected segments render label-only.
  final List<IconData>? icons;

  /// Marker and selected-label colour. Defaults to the theme primary; pass a
  /// feature accent to tint the control.
  final Color? color;
  final int index;
  final ValueChanged<int> onTap;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final surfaces = context.surfaces;
    final motion = context.motion;
    final accent = color ?? cs.primary;

    return Padding(
      padding: margin,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      // Scale down rather than truncate: several of these
                      // carry three or four long labels on a 360dp screen.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icons != null && i < icons!.length) ...[
                              Icon(
                                icons![i],
                                size: 15,
                                color: i == index
                                    ? accent
                                    : surfaces.textTertiary,
                              ),
                              const SizedBox(width: AppSpacing.xs + 2),
                            ],
                            Text(
                              labels[i],
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: tt.labelLarge
                                  ?.copyWith(
                                    color: i == index
                                        ? surfaces.textPrimary
                                        : surfaces.textTertiary,
                                  )
                                  .weight(
                                    i == index
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // The unselected segments carry the hairline, so the rule
                    // runs unbroken under the whole row and the marker reads as
                    // a thickening of it rather than a separate bar.
                    AnimatedContainer(
                      duration: motion.short,
                      curve: motion.standardCurve,
                      height: i == index ? 2 : AppSurfaces.hairlineWidth,
                      margin: EdgeInsets.only(
                        bottom: i == index ? 0 : 2 - AppSurfaces.hairlineWidth,
                      ),
                      color: i == index ? accent : surfaces.hairline,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
