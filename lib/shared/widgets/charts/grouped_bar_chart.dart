import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// One series of bars. With a single series the bars are wide; with two (e.g.
/// income vs expense) they sit side-by-side within each x bucket.
class BarSeries {
  const BarSeries({
    required this.label,
    required this.color,
    required this.values,
  });

  final String label;
  final Color color;
  final List<double> values;
}

/// A themed grouped bar chart built on `fl_chart`. Handles empty data, thins
/// x-labels, and auto-scales the y-axis. Wrap it in a [GlassCard] at the call
/// site and render the legend from the [BarSeries] labels.
class GroupedBarChart extends StatelessWidget {
  const GroupedBarChart({
    super.key,
    required this.xLabels,
    required this.series,
    this.height = 160,
    this.leftFormatter,
    this.maxXLabels = 7,
  });

  final List<String> xLabels;
  final List<BarSeries> series;
  final double height;
  final String Function(double)? leftFormatter;
  final int maxXLabels;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final count = xLabels.length;
    if (count == 0 || series.isEmpty) return SizedBox(height: height);

    var maxV = 0.0;
    for (final s in series) {
      for (final v in s.values) {
        maxV = math.max(maxV, v);
      }
    }
    if (maxV <= 0) maxV = 1;
    final maxY = maxV * 1.18;

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < count; i++) {
      final rods = <BarChartRodData>[
        for (final s in series)
          BarChartRodData(
            toY: i < s.values.length ? s.values[i] : 0.0,
            color: s.color,
            width: series.length == 1 ? 14 : 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
      ];
      groups.add(BarChartGroupData(x: i, barRods: rods, barsSpace: 3));
    }

    final step = (count / maxXLabels).ceil().clamp(1, count);

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          minY: 0,
          barGroups: groups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 3,
            getDrawingHorizontalLine: (v) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.25),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: leftFormatter != null,
                reservedSize: 42,
                interval: maxY / 3,
                getTitlesWidget: (value, meta) {
                  final f = leftFormatter;
                  if (f == null) return const SizedBox.shrink();
                  return Text(
                    f(value),
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 9,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= xLabels.length) {
                    return const SizedBox.shrink();
                  }
                  if (i % step != 0 && i != count - 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      xLabels[i],
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
