import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../shared/design/tokens.dart';
import '../../../shared/utils/insights_range.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/charts/activity_heatmap.dart';
import '../../../shared/widgets/charts/grouped_bar_chart.dart';
import '../../../shared/widgets/charts/trend_line_chart.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/segmented_control.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../mentor/presentation/mentor_providers.dart';
import '../data/gym_insights_service.dart';
import 'gym_insights_providers.dart';
import 'providers.dart';

/// The gym "Insights" tab: a range selector, session KPIs, workouts-over-time
/// bars, a consistency heatmap, body-measurement trend charts, and a scrollable
/// workout-history list. Session analytics come from workout dates (what's
/// tracked); there is no per-set volume data.
class GymInsightsView extends ConsumerWidget {
  const GymInsightsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(gymRangeProvider);
    const ranges = InsightsRange.values;
    final insightsA = ref.watch(gymInsightsProvider);

    return Column(
      children: [
        SegmentedControl(
          labels: [for (final r in ranges) r.label],
          index: ranges.indexOf(range),
          color: DomainColors.gym,
          onTap: (i) => ref.read(gymRangeProvider.notifier).state = ranges[i],
        ),
        Expanded(
          child: insightsA.when(
            loading: () => const AppLoading(),
            error: (e, _) => AppErrorView(error: e),
            data: (gi) {
              final hasProgression = ref
                  .watch(progressionExerciseNamesProvider)
                  .isNotEmpty;
              if (!gi.hasSessions &&
                  gi.measurements.isEmpty &&
                  !hasProgression) {
                return const AppEmptyState(
                  icon: Icons.insights_rounded,
                  title: 'Nothing to chart yet',
                  message:
                      'Log a workout or record a measurement to see trends here.',
                  accent: DomainColors.gym,
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
                children: [
                  _KpiStrip(gi: gi),
                  if (gi.hasSessions) ...[
                    _WorkoutsCard(gi: gi),
                    _ConsistencyCard(gi: gi),
                  ],
                  const _ProgressionCard(),
                  for (final m in gi.measurements) _MeasurementCard(series: m),
                  if (gi.sessions.isNotEmpty) _HistoryCard(gi: gi),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── KPI strip ────────────────────────────────────────────────────────────────

class _KpiStrip extends ConsumerWidget {
  const _KpiStrip({required this.gi});
  final GymInsights gi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(gymForecastProvider).value;
    final cards = <Widget>[
      MetricCard(
        label: 'Workouts',
        value: '${gi.totalSessions}',
        icon: Icons.fitness_center_rounded,
        accent: DomainColors.gym,
      ),
      MetricCard(
        label: 'Per week',
        value: gi.sessionsPerWeek.toStringAsFixed(1),
        icon: Icons.calendar_view_week_rounded,
        accent: DomainColors.gym,
      ),
      MetricCard(
        label: 'Week streak',
        value: '${forecast?.currentWeekStreak ?? 0}w',
        icon: Icons.local_fire_department_rounded,
        accent: DomainColors.warning,
      ),
      MetricCard(
        label: 'Last workout',
        value: _lastLabel(forecast?.lastSessionDaysAgo),
        icon: Icons.event_available_rounded,
        accent: DomainColors.tasks,
      ),
    ];
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => SizedBox(width: 132, child: cards[i]),
      ),
    );
  }

  String _lastLabel(int? daysAgo) {
    if (daysAgo == null) return '—';
    if (daysAgo == 0) return 'Today';
    if (daysAgo == 1) return '1d ago';
    return '${daysAgo}d ago';
  }
}

// ── workouts over time ───────────────────────────────────────────────────────

class _WorkoutsCard extends StatelessWidget {
  const _WorkoutsCard({required this.gi});
  final GymInsights gi;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.bar_chart_rounded,
      title: 'Workouts over time',
      subtitle: '${gi.totalSessions} sessions · ${gi.activeDays} active days',
      child: GroupedBarChart(
        xLabels: [for (final b in gi.bars) b.label],
        series: [
          BarSeries(
            label: 'Workouts',
            color: DomainColors.gym,
            values: [for (final b in gi.bars) b.value],
          ),
        ],
      ),
    );
  }
}

// ── consistency heatmap ──────────────────────────────────────────────────────

class _ConsistencyCard extends StatelessWidget {
  const _ConsistencyCard({required this.gi});
  final GymInsights gi;

  @override
  Widget build(BuildContext context) {
    final cells = [
      for (final d in gi.days)
        HeatCell(
          date: d.date,
          intensity: d.count == 0 ? 0 : (0.45 + 0.25 * d.count).clamp(0.0, 1.0),
        ),
    ];
    return _SectionCard(
      icon: Icons.grid_view_rounded,
      title: 'Consistency',
      subtitle: 'Training days in range',
      child: ActivityHeatmap(cells: cells, color: DomainColors.gym),
    );
  }
}

// ── body measurement trend ───────────────────────────────────────────────────

class _MeasurementCard extends StatelessWidget {
  const _MeasurementCard({required this.series});
  final MeasurementSeries series;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final unit = series.type.unit ?? '';
    final change = series.change;
    final flat = change.abs() < 1e-9;
    final up = change > 0;

    return _SectionCard(
      icon: Icons.straighten_rounded,
      title: series.type.name,
      subtitle: '${_fmt(series.latest)}$unit now',
      trailing: flat
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  up ? Icons.north_east_rounded : Icons.south_east_rounded,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 2),
                Text(
                  '${_fmt(change.abs())}$unit',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
      child: series.points.length < 2
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Only one record in range',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            )
          : TrendLineChart(
              height: 130,
              xLabels: series.labels,
              leftFormatter: _fmt,
              series: [
                LineSeries(
                  values: [for (final v in series.values) v],
                  color: DomainColors.gym,
                  fill: true,
                ),
              ],
            ),
    );
  }
}

// ── history ──────────────────────────────────────────────────────────────────

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.gi});
  final GymInsights gi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysById = {
      for (final d
          in (ref.watch(allProgramDaysProvider).value ?? const <ProgramDay>[]))
        d.id: d,
    };
    final programsById = {
      for (final p
          in (ref.watch(programsStreamProvider).value ?? const <Program>[]))
        p.id: p,
    };

    return _SectionCard(
      icon: Icons.history_rounded,
      title: 'Workout history',
      subtitle: '${gi.sessions.length} in range',
      child: Column(
        children: [
          for (final s in gi.sessions)
            _HistoryRow(
              session: s,
              day: daysById[s.programDayId],
              programsById: programsById,
              onDelete: () => ref.read(gymDaoProvider).deleteSession(s.id),
            ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.session,
    required this.day,
    required this.programsById,
    required this.onDelete,
  });
  final DaySession session;
  final ProgramDay? day;
  final Map<String, Program> programsById;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final program = day == null ? null : programsById[day!.programId];
    final title = day == null
        ? 'Workout'
        : program == null
        ? day!.name
        : '${program.name} · ${day!.name}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: DomainColors.gym.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: DomainColors.gym,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateFormat.MMMEd().add_jm().format(session.playedAt),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 18, color: cs.error),
            onPressed: onDelete,
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

// ── progression ──────────────────────────────────────────────────────────────

class _ProgressionCard extends ConsumerWidget {
  const _ProgressionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(progressionExerciseNamesProvider);
    if (names.isEmpty) return const SizedBox.shrink();
    final prog = ref.watch(exerciseProgressionProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return _SectionCard(
      icon: Icons.trending_up_rounded,
      title: 'Progression',
      subtitle: 'All-time · from your logged set edits',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: names.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => AppChip(
                label: names[i],
                color: DomainColors.gym,
                selected: names[i] == prog?.name,
                onTap: () =>
                    ref
                            .read(selectedProgressionExerciseProvider.notifier)
                            .state =
                        names[i],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (prog == null || !prog.hasPoints)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No history yet for this movement.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'Top set',
                    value: _fmt(prog.latestWeight),
                    accent: DomainColors.gym,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricCard(
                    label: 'Est. 1RM',
                    value: _fmt(prog.latest1RM),
                    accent: DomainColors.warning,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricCard(
                    label: 'Best',
                    value: _fmt(prog.bestWeight),
                    accent: DomainColors.tasks,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (prog.hasTrend) ...[
              _legend(context, const [
                (DomainColors.gym, 'Top weight'),
                (DomainColors.warning, 'Est. 1RM'),
              ]),
              const SizedBox(height: AppSpacing.sm),
              TrendLineChart(
                height: 150,
                xLabels: prog.isoDays,
                leftFormatter: _fmt,
                series: [
                  LineSeries(
                    values: [for (final p in prog.points) p.topWeight],
                    color: DomainColors.gym,
                    fill: true,
                  ),
                  LineSeries(
                    values: [for (final p in prog.points) p.est1RM],
                    color: DomainColors.warning,
                  ),
                ],
              ),
            ] else
              Text(
                'One entry so far — edit a set again to see the trend.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
          ],
        ],
      ),
    );
  }
}

// ── shared section card ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: DomainColors.gym.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: DomainColors.gym, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

Widget _legend(BuildContext context, List<(Color, String)> items) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
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
                borderRadius: BorderRadius.circular(3),
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
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
