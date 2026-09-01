part of '../../insights_view.dart';

// The activity heatmap, and shared chart furniture.

class _ConsistencyCard extends ConsumerWidget {
  const _ConsistencyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(insightsRangeSummaryProvider).value;
    if (rs == null || rs.days.length < 2) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final cells = [
      for (final d in rs.days) HeatCell(date: d.date, intensity: _intensity(d)),
    ];
    if (cells.every((c) => c.intensity <= 0)) return const SizedBox.shrink();

    return InsightsCard(
      icon: Icons.grid_view_rounded,
      color: cs.primary,
      title: 'Consistency',
      subtitle: 'Daily activity across all areas',
      takeaway: _consistencyTakeaway(rs, cells),
      child: ActivityHeatmap(cells: cells, color: cs.primary),
    );
  }

  double _intensity(DaySummary d) {
    if (!d.hasActivity) return 0;
    var v = 0.25;
    if (d.tasksDue > 0) v = 0.25 + 0.55 * d.taskCompletion;
    if (d.workedOut) v += 0.2;
    if (d.notesCount > 0) v += 0.1;
    return v.clamp(0.0, 1.0);
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const AppCard(
    child: SizedBox(height: 120, child: AppLoading()),
  );
}

Widget _legend(List<(Color, String)> items) {
  return Builder(
    builder: (context) {
      final tt = Theme.of(context).textTheme;
      final cs = Theme.of(context).colorScheme;
      return Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          for (final (color, label) in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
        ],
      );
    },
  );
}


/// How much of the range had any activity at all.
String? _consistencyTakeaway(RangeSummary rs, List<HeatCell> cells) {
  final active = cells.where((c) => c.intensity > 0).length;
  if (cells.isEmpty) return null;
  final percent = (active / cells.length * 100).round();
  return 'Something was logged on $active of ${cells.length} days, $percent%.';
}
