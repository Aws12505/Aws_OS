import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// One line on a [TrendLineChart]. Nulls in [values] create gaps (the point is
/// skipped), which lets sparse series like mood/energy render cleanly.
class LineSeries {
  const LineSeries({
    required this.values,
    required this.color,
    this.label,
    this.fill = false,
  });

  final List<double?> values;
  final Color color;
  final String? label;
  final bool fill;
}

/// A themed multi-series line chart built on `fl_chart`. Handles empty, flat and
/// negative data, auto-frames the y-range, and thins x-labels so they never
/// overlap. Wrap it in a [AppCard] at the call site.
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
    required this.series,
    this.xLabels = const [],
    this.height = 150,
    this.leftFormatter,
    this.maxXLabels = 6,
  });

  final List<LineSeries> series;
  final List<String> xLabels;
  final double height;

  /// When provided, renders a compact left value axis using this formatter.
  final String Function(double)? leftFormatter;
  final int maxXLabels;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final count = series.fold<int>(0, (m, s) => math.max(m, s.values.length));
    if (count < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Not enough data yet',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    final allVals = <double>[
      for (final s in series)
        for (final v in s.values)
          if (v != null && v.isFinite) v,
    ];
    if (allVals.isEmpty) return SizedBox(height: height);

    var minY = allVals.reduce(math.min);
    var maxY = allVals.reduce(math.max);
    if ((maxY - minY).abs() < 1e-9) {
      final pad = maxY.abs() < 1e-9 ? 1.0 : maxY.abs() * 0.5;
      minY -= pad;
      maxY += pad;
    } else {
      final pad = (maxY - minY) * 0.12;
      minY -= pad;
      maxY += pad;
    }
    final span = maxY - minY;

    final lineBars = <LineChartBarData>[];
    for (final s in series) {
      final spots = <FlSpot>[];
      for (var i = 0; i < s.values.length; i++) {
        final v = s.values[i];
        if (v != null && v.isFinite) spots.add(FlSpot(i.toDouble(), v));
      }
      if (spots.isEmpty) continue;
      lineBars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          preventCurveOverShooting: true,
          color: s.color,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: s.fill,
            color: s.color.withValues(alpha: 0.12),
          ),
        ),
      );
    }

    final step = (count / maxXLabels).ceil().clamp(1, count);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (count - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineBarsData: lineBars,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: span / 3,
            getDrawingHorizontalLine: (v) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.25),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
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
                interval: span / 3,
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
                showTitles: xLabels.isNotEmpty,
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
