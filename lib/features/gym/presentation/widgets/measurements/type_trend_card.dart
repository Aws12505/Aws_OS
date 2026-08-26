part of '../../screens/measurements_view.dart';

// One measurement, its latest value and its direction.

class _TypeTrendCard extends StatelessWidget {
  const _TypeTrendCard({required this.type, required this.series});

  final MeasurementType type;
  final List<double> series;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final surfaces = context.surfaces;
    final accent = context.sem.gym;

    final latest = series.last;
    final previous = series.length >= 2 ? series[series.length - 2] : null;
    final delta = previous == null ? null : latest - previous;
    final rising = (delta ?? 0) > 0;

    return SizedBox(
      height: 154,
      child: AppCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              type.name,
              style: tt.labelLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _fmt(latest),
                      maxLines: 1,
                      style: tt.headlineSmall,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  type.unit ?? '',
                  style: tt.bodySmall?.copyWith(color: surfaces.textTertiary),
                ),
              ],
            ),
            // Deliberately not green-up, red-down. This card shows body
            // measurements, and there is no direction that is good for all of
            // them: gaining on a lift and gaining on a waist are not the same
            // news, and the app has no way to know which one you want.
            if (delta != null && delta != 0)
              Row(
                children: [
                  Icon(
                    rising
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 12,
                    color: surfaces.textSecondary,
                  ),
                  Flexible(
                    child: Text(
                      '${_fmt(delta.abs())}${type.unit ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.numericSmall.copyWith(
                        color: surfaces.textSecondary,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                series.length == 1
                    ? 'one reading'
                    : '${series.length} readings',
                style: tt.labelSmall?.copyWith(
                  color: surfaces.textTertiary,
                  letterSpacing: 0,
                ),
              ),
            const Spacer(),
            Sparkline(values: series, color: accent.base, fill: true),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
