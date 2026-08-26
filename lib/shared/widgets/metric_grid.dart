import 'package:flutter/material.dart';

import '../design/app_theme.dart';

/// Summary tiles laid out so all of them are visible at once.
///
/// Both insight views used to put these in a horizontal scroller, which hid
/// half the numbers behind a swipe. A summary you have to scroll is not a
/// summary, so this wraps instead: as many across as fit, then a new row.
class MetricGrid extends StatelessWidget {
  const MetricGrid({
    super.key,
    required this.tiles,
    this.minTileWidth = 150,
    this.maxPerRow = 4,
    this.spacing = AppSpacing.sm,
  });

  final List<Widget> tiles;

  /// Below this the row splits. Tuned so a tile still fits a label plus a
  /// number without the number shrinking away.
  final double minTileWidth;

  final int maxPerRow;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final fits = ((constraints.maxWidth + spacing) /
                (minTileWidth + spacing))
            .floor();
        final perRow = fits.clamp(1, maxPerRow);

        return Column(
          children: [
            for (var start = 0; start < tiles.length; start += perRow)
              Padding(
                padding: EdgeInsets.only(
                  bottom: start + perRow < tiles.length ? spacing : 0,
                ),
                // IntrinsicHeight so tiles in a row match, without asking the
                // Row for an unbounded height inside a scroll view.
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = start; i < start + perRow; i++) ...[
                        if (i > start) SizedBox(width: spacing),
                        Expanded(
                          child: i < tiles.length
                              ? tiles[i]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
