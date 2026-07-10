import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// One donut slice.
class DonutDatum {
  const DonutDatum({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;
}

/// A clean donut with a value in the hole and an amount/percentage legend —
/// the app's standard replacement for a bare pie. Wrap it in a [GlassCard] at
/// the call site.
class CategoryDonut extends StatelessWidget {
  const CategoryDonut({
    super.key,
    required this.data,
    required this.centerValue,
    this.centerLabel,
    this.legendValue,
    this.size = 134,
    this.maxLegend = 6,
  });

  final List<DonutDatum> data;
  final String centerValue;
  final String? centerLabel;

  /// Optional per-slice value formatter shown in the legend (e.g. compact
  /// amount). When null, the legend shows only the percentage.
  final String Function(double value)? legendValue;
  final double size;
  final int maxLegend;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (data.isEmpty) {
      return SizedBox(
        height: size,
        child: Center(
          child: Text(
            'No data',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }
    final total = data.fold<double>(0, (s, d) => s + d.value);
    final ring = size / 2 - 22;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                  centerSpaceRadius: (size / 2) - ring - 2,
                  borderData: FlBorderData(show: false),
                  pieTouchData: PieTouchData(enabled: false),
                  sections: [
                    for (final d in data)
                      PieChartSectionData(
                        value: d.value <= 0 ? 0.0001 : d.value,
                        color: d.color,
                        radius: ring,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerValue,
                    maxLines: 1,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (centerLabel != null)
                    Text(
                      centerLabel!,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final d in data.take(maxLegend)) _row(context, d, total),
              if (data.length > maxLegend)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '+${data.length - maxLegend} more',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, DonutDatum d, double total) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pct = total <= 0 ? 0 : (d.value / total * 100).round();
    final trailing = legendValue != null
        ? '${legendValue!(d.value)} · $pct%'
        : '$pct%';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: d.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              d.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            trailing,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
