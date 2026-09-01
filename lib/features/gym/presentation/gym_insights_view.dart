import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../shared/design/app_theme.dart';
import '../../../shared/utils/insights_range.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/charts/activity_heatmap.dart';
import '../../../shared/widgets/charts/grouped_bar_chart.dart';
import '../../../shared/widgets/charts/trend_line_chart.dart';
import '../../../shared/widgets/insights_card.dart';
import '../../../shared/widgets/metric_grid.dart';
import '../../../shared/widgets/segmented_control.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../mentor/presentation/mentor_providers.dart';
import '../data/gym_insights_service.dart';
import 'exercise_identity.dart';
import 'gym_insights_providers.dart';
import 'providers.dart';

/// The gym Insights tab: a range selector, session KPIs, workouts over time, a
/// consistency heatmap, body-measurement trends, per-exercise progression, and
/// the workout history.
///
/// Session analytics come from workout dates, which is what the app records.
/// There is no per-set volume data, so nothing here claims any.
class GymInsightsView extends ConsumerWidget {
  const GymInsightsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(gymRangeProvider);
    const ranges = InsightsRange.values;
    final insightsA = ref.watch(gymInsightsProvider);
    final accent = context.sem.gym;

    return Column(
      children: [
        SegmentedControl(
          labels: [for (final r in ranges) r.label],
          index: ranges.indexOf(range),
          color: accent.base,
          onTap: (i) => ref.read(gymRangeProvider.notifier).state = ranges[i],
        ),
        Expanded(
          child: insightsA.when(
            loading: () => const AppLoading(message: 'Crunching your training'),
            error: (e, _) => AppErrorView(error: e),
            data: (gi) {
              final hasProgression = ref
                  .watch(progressionExerciseNamesProvider)
                  .isNotEmpty;
              if (!gi.hasSessions &&
                  gi.measurements.isEmpty &&
                  !hasProgression) {
                return AppEmptyState(
                  icon: Icons.insights_rounded,
                  title: 'Nothing to chart yet',
                  message:
                      'Tick a workout off or record a measurement, and the '
                      'trends start filling in here.',
                  accent: accent.base,
                );
              }
              return ListView(
                // No horizontal padding: every child carries the page margin
                // itself, the same as the other two insights views.
                padding: const EdgeInsets.only(bottom: AppInsets.listBottom),
                children: [
                  _KpiGrid(gi: gi),
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

// ── KPI grid ─────────────────────────────────────────────────────────────────

/// Four numbers, all visible at once.
///
/// These used to sit in a horizontal scroller, which hid half of them behind a
/// swipe. A summary you have to scroll is not a summary.
class _KpiGrid extends ConsumerWidget {
  const _KpiGrid({required this.gi});

  final GymInsights gi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(gymForecastProvider).value;
    final sem = context.sem;

    final cards = <Widget>[
      MetricCard(
        label: 'Workouts',
        value: '${gi.totalSessions}',
        icon: Icons.fitness_center_rounded,
        accent: sem.gym.base,
      ),
      MetricCard(
        label: 'Per week',
        value: gi.sessionsPerWeek.toStringAsFixed(1),
        icon: Icons.calendar_view_week_rounded,
        accent: sem.gym.base,
      ),
      MetricCard(
        label: 'Week streak',
        value: '${forecast?.currentWeekStreak ?? 0}w',
        icon: Icons.local_fire_department_rounded,
        accent: sem.warning.base,
      ),
      MetricCard(
        label: 'Last workout',
        value: _lastLabel(forecast?.lastSessionDaysAgo),
        icon: Icons.event_available_rounded,
        accent: sem.tasks.base,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: MetricGrid(tiles: cards),
    );
  }

  String _lastLabel(int? daysAgo) => switch (daysAgo) {
    null => 'None',
    0 => 'Today',
    1 => '1d ago',
    final d => '${d}d ago',
  };
}

// ── workouts over time ───────────────────────────────────────────────────────

class _WorkoutsCard extends StatelessWidget {
  const _WorkoutsCard({required this.gi});

  final GymInsights gi;

  @override
  Widget build(BuildContext context) {
    final busiest = gi.bars.isEmpty
        ? null
        : gi.bars.reduce((a, b) => b.value > a.value ? b : a);

    return InsightsCard(
      color: context.sem.gym.base,
      icon: Icons.bar_chart_rounded,
      title: 'Workouts over time',
      subtitle: '${gi.totalSessions} sessions across ${gi.activeDays} days',
      takeaway: busiest == null || busiest.value == 0
          ? null
          : 'Busiest stretch was ${busiest.label}, with '
                '${busiest.value.round()} '
                '${busiest.value.round() == 1 ? 'session' : 'sessions'}.',
      child: GroupedBarChart(
        xLabels: [for (final b in gi.bars) b.label],
        series: [
          BarSeries(
            label: 'Workouts',
            color: context.sem.gym.base,
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
    final rate = gi.days.isEmpty ? 0.0 : gi.activeDays / gi.days.length;

    return InsightsCard(
      color: context.sem.gym.base,
      icon: Icons.grid_view_rounded,
      title: 'Consistency',
      subtitle: 'Training days in range',
      takeaway: gi.days.isEmpty
          ? null
          : 'You trained on ${(rate * 100).round()}% of days in this range.',
      child: ActivityHeatmap(cells: cells, color: context.sem.gym.base),
    );
  }
}

// ── body measurement trend ───────────────────────────────────────────────────

class _MeasurementCard extends StatelessWidget {
  const _MeasurementCard({required this.series});

  final MeasurementSeries series;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final tt = Theme.of(context).textTheme;
    final unit = series.type.unit ?? '';
    final change = series.change;
    final flat = change.abs() < 1e-9;
    final rising = change > 0;

    return InsightsCard(
      color: context.sem.gym.base,
      icon: Icons.straighten_rounded,
      title: series.type.name,
      subtitle: '${_fmt(series.latest)}$unit now',
      takeaway: series.points.length < 2
          ? null
          : flat
          ? 'Unchanged across this range.'
          : '${rising ? 'Up' : 'Down'} ${_fmt(change.abs())}$unit across '
                'this range, over ${series.points.length} readings.',
      // Direction, not judgement. Up is not good news for every measurement,
      // and the app has no way to know which ones you want going which way.
      trailing: flat
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  rising ? Icons.north_east_rounded : Icons.south_east_rounded,
                  size: 14,
                  color: surfaces.textSecondary,
                ),
                const SizedBox(width: 2),
                Text(
                  '${_fmt(change.abs())}$unit',
                  style: context.type.numericSmall.copyWith(
                    color: surfaces.textSecondary,
                  ),
                ),
              ],
            ),
      child: series.points.length < 2
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'Only one reading in this range, so there is no line to draw '
                'yet.',
                style: tt.bodySmall?.copyWith(color: surfaces.textSecondary),
              ),
            )
          : TrendLineChart(
              height: 130,
              xLabels: series.labels,
              leftFormatter: _fmt,
              series: [
                LineSeries(
                  values: [for (final v in series.values) v],
                  color: context.sem.gym.base,
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
    final surfaces = context.surfaces;

    return InsightsCard(
      color: context.sem.gym.base,
      icon: Icons.history_rounded,
      title: 'Workout history',
      subtitle: '${gi.sessions.length} in range',
      child: Column(
        children: [
          for (var i = 0; i < gi.sessions.length; i++) ...[
            // Hairline between rows rather than a box around each: openGym's
            // list treatment, and it reads far calmer at this density.
            if (i > 0) Divider(height: 1, color: surfaces.hairline),
            _HistoryRow(
              session: gi.sessions[i],
              day: daysById[gi.sessions[i].programDayId],
              programsById: programsById,
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({
    required this.session,
    required this.day,
    required this.programsById,
  });

  final DaySession session;
  final ProgramDay? day;
  final Map<String, Program> programsById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final accent = context.sem.gym;
    final tt = Theme.of(context).textTheme;
    final program = day == null ? null : programsById[day!.programId];
    final title = day == null
        ? 'Workout'
        : program == null
        ? day!.name
        : '${program.name}, ${day!.name}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.container,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.fitness_center_rounded,
              color: accent.onContainer,
              size: 17,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateFormat.MMMEd().add_jm().format(session.playedAt),
                  style: tt.bodySmall?.copyWith(color: surfaces.textTertiary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete this session',
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: surfaces.textTertiary,
            ),
            onPressed: () async {
              final dao = ref.read(gymDaoProvider);
              final dayId = session.programDayId;
              final playedAt = session.playedAt;
              final note = session.note;
              await dao.deleteSession(session.id);
              if (!context.mounted) return;
              showUndoSnackBar(
                context,
                message: 'Deleted $title.',
                onUndo: () => dao.insertSession(
                  dayId: dayId,
                  playedAt: playedAt,
                  note: note,
                ),
              );
            },
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
    final sem = context.sem;
    final surfaces = context.surfaces;
    final tt = Theme.of(context).textTheme;

    return InsightsCard(
      color: context.sem.gym.base,
      icon: Icons.trending_up_rounded,
      title: 'Progression',
      subtitle: 'All time, from the sets you have logged',
      takeaway: prog == null || !prog.hasPoints
          ? null
          : 'Best ${prog.name} so far is ${_fmt(prog.bestWeight)}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: names.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) => AppChip(
                label: names[i],
                // Same colour the movement gets everywhere else, so the chip,
                // the set card and the history sheet agree.
                color: ExerciseIdentity.colorOf(context, names[i]),
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
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                'No history for this movement yet.',
                style: tt.bodySmall?.copyWith(color: surfaces.textSecondary),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'Top set',
                    value: _fmt(prog.latestWeight),
                    accent: sem.gym.base,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MetricCard(
                    label: 'Est. 1RM',
                    value: _fmt(prog.latest1RM),
                    accent: sem.warning.base,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MetricCard(
                    label: 'Best',
                    value: _fmt(prog.bestWeight),
                    accent: sem.tasks.base,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (prog.hasTrend) ...[
              _legend(context, [
                (sem.gym.base, 'Top weight'),
                (sem.warning.base, 'Est. 1RM'),
              ]),
              const SizedBox(height: AppSpacing.sm),
              TrendLineChart(
                height: 150,
                xLabels: prog.isoDays,
                leftFormatter: _fmt,
                series: [
                  LineSeries(
                    values: [for (final p in prog.points) p.topWeight],
                    color: sem.gym.base,
                    fill: true,
                  ),
                  LineSeries(
                    values: [for (final p in prog.points) p.est1RM],
                    color: sem.warning.base,
                  ),
                ],
              ),
            ] else
              Text(
                'One entry so far. Log this movement again to see the trend.',
                style: tt.bodySmall?.copyWith(color: surfaces.textSecondary),
              ),
          ],
        ],
      ),
    );
  }
}

// ── shared section card ──────────────────────────────────────────────────────

Widget _legend(BuildContext context, List<(Color, String)> items) {
  final surfaces = context.surfaces;
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
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: surfaces.textSecondary,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
    ],
  );
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
