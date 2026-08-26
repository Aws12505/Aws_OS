import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// One day in an [ActivityHeatmap]. [intensity] is clamped to 0..1 and drives
/// how strongly the accent color shows through.
class HeatCell {
  const HeatCell({required this.date, required this.intensity});

  final DateTime date;
  final double intensity;
}

/// A GitHub-style contributions grid: one column per week (Mon→Sun rows),
/// colored by each day's [HeatCell.intensity]. Scrolls horizontally when the
/// range is long. Days with no cell render as faint empty squares.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({
    super.key,
    required this.cells,
    required this.color,
    this.cellSize = 15,
    this.gap = 3,
  });

  final List<HeatCell> cells;
  final Color color;
  final double cellSize;
  final double gap;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (cells.isEmpty) return const SizedBox.shrink();

    final byDay = {for (final c in cells) _day(c.date): c};
    final days = byDay.keys.toList()..sort();
    final first = days.first;
    final last = days.last;
    final empty = cs.outlineVariant.withValues(alpha: 0.22);

    final columns = <Widget>[];
    var weekStart = _mondayOf(first);
    var guard = 0;
    while (!weekStart.isAfter(last) && guard < 120) {
      guard++;
      final squares = <Widget>[];
      for (var i = 0; i < 7; i++) {
        final day = DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day + i,
        );
        final cell = byDay[day];
        final inRange = !day.isBefore(first) && !day.isAfter(last);
        final fill = (cell == null || cell.intensity <= 0 || !inRange)
            ? (inRange ? empty : Colors.transparent)
            : Color.lerp(
                empty,
                color,
                cell.intensity.clamp(0.0, 1.0) * 0.85 + 0.15,
              )!;
        squares.add(
          Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            ),
          ),
        );
      }
      columns.add(
        Padding(
          padding: EdgeInsets.only(right: gap),
          child: Column(mainAxisSize: MainAxisSize.min, children: squares),
        ),
      );
      weekStart = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
    }

    // Left weekday labels (Mon / Wed / Fri) aligned to the grid rows.
    const dayLabels = ['M', '', 'W', '', 'F', '', ''];
    final labelColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 7; i++)
          Container(
            height: cellSize,
            margin: EdgeInsets.only(bottom: gap, right: 6),
            alignment: Alignment.centerRight,
            child: Text(
              dayLabels[i],
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 9,
              ),
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelColumn, ...columns],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Less',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 9,
              ),
            ),
            const SizedBox(width: 6),
            for (final a in const [0.15, 0.4, 0.65, 1.0])
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: Color.lerp(empty, color, a),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
              ),
            const SizedBox(width: 3),
            Text(
              'More',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
