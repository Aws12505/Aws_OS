import 'package:aws_os/app/theme.dart';
import 'package:aws_os/shared/design/app_theme.dart';
import 'package:aws_os/shared/widgets/app_buttons.dart';
import 'package:aws_os/shared/widgets/stagger.dart';
import 'package:aws_os/shared/widgets/section_header.dart';
import 'package:aws_os/shared/widgets/metric_grid.dart';
import 'package:aws_os/shared/widgets/insights_card.dart';
import 'package:aws_os/shared/widgets/date_range_row.dart';
import 'package:aws_os/shared/widgets/app_stepper.dart';
import 'package:aws_os/shared/widgets/app_filter_bar.dart';
import 'package:aws_os/shared/widgets/app_chip.dart';
import 'package:aws_os/shared/widgets/app_empty_state.dart';
import 'package:aws_os/shared/widgets/app_error_view.dart';
import 'package:aws_os/shared/widgets/app_loading.dart';
import 'package:aws_os/shared/widgets/count_badge.dart';
import 'package:aws_os/shared/widgets/glass.dart';
import 'package:aws_os/shared/widgets/segmented_control.dart';
import 'package:aws_os/shared/widgets/stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the two ends of the user-facing text-size slider.
///
/// Flutter surfaces `RenderFlex overflowed` as a test exception, so pumping the
/// shared kit at the smallest and largest scale finds clipping mechanically
/// instead of by squinting at a device. The kit is the right target: a fixed
/// height or a missing `Flexible` in one of these widgets is a bug on every
/// screen at once.
///
/// 360dp is the narrowest width in common use. Both brightnesses run because
/// the surface tokens differ between them.
void main() {
  const scales = <double>[0.85, 1.0, 1.30];
  const brightnesses = <Brightness>[Brightness.light, Brightness.dark];

  for (final scale in scales) {
    for (final brightness in brightnesses) {
      testWidgets(
        'shared widgets do not overflow at fontScale $scale (${brightness.name})',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(360, 3000));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(
                ThemeSettings.defaults.copyWith(fontScale: scale),
                brightness,
              ),
              home: const Scaffold(body: SingleChildScrollView(child: _Kit())),
            ),
          );
          // Not pumpAndSettle: AppLoading spins indefinitely by design, so
          // nothing here ever settles. Advancing past the stagger delay is
          // enough to fire its timer and finish the entry animation.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));

          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('the type scale carries the slider, including tracking', (
    tester,
  ) async {
    TextTheme themeAt(double scale) => buildTheme(
      ThemeSettings.defaults.copyWith(fontScale: scale),
      Brightness.dark,
    ).textTheme;

    final small = themeAt(0.85).labelSmall!;
    final large = themeAt(1.30).labelSmall!;

    expect(large.fontSize! > small.fontSize!, isTrue);
    // Material specifies tracking in logical pixels, so it has to scale with
    // the size or text reads too tight at 1.30 and too loose at 0.85.
    expect(large.letterSpacing! > small.letterSpacing!, isTrue);
  });

  testWidgets('numeric roles request tabular figures', (tester) async {
    final tokens = AppTypeTokens.resolve(family: 'system', scale: 1);
    for (final style in [
      tokens.numeric,
      tokens.numericLarge,
      tokens.numericSmall,
    ]) {
      expect(
        style.fontFeatures,
        contains(const FontFeature.tabularFigures()),
        reason: 'numbers jitter horizontally without tabular figures',
      );
    }
  });
}

/// Every shared widget that renders text, in one column.
class _Kit extends StatelessWidget {
  const _Kit();

  // Controllers for the stepper, which needs real ones to render a value.
  static final _reps = TextEditingController(text: '8');
  static final _weight = TextEditingController(text: '62.5');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = context.sem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'A screen title that runs on',
          status: 'Trained today, 4 week streak',
          statusIcon: Icons.bolt_rounded,
        ),
        AppFilterBar(
          activeCount: 3,
          color: sem.tasks.base,
          onOpenFilters: () {},
          onClear: () {},
        ),
        DateRangeRow(
          from: DateTime(2026, 8, 1),
          to: DateTime(2026, 8, 26),
          selected: true,
          color: sem.transfer.base,
          onPicked: (_, _) {},
          onCleared: () {},
        ),
        const SectionLabel('Trends, all time'),
        SegmentedControl(
          labels: const ['Insights', 'Measurements', 'Programs'],
          icons: const [
            Icons.insights_rounded,
            Icons.straighten_rounded,
            Icons.list_alt_rounded,
          ],
          index: 0,
          onTap: (_) {},
        ),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.trending_up_rounded,
                color: sem.income.base,
                label: 'Net this month',
                value: '1,284,930.50',
                sub: 'across 3 currencies',
              ),
            ),
            Expanded(
              child: StatTile(
                icon: Icons.fitness_center_rounded,
                color: sem.gym.base,
                label: 'Week streak',
                value: '12w',
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Estimated 1RM',
                value: '102.5 kg',
                accent: sem.gym.base,
              ),
            ),
            Expanded(
              child: MetricCard(label: 'Sessions', value: '48'),
            ),
          ],
        ),
        const GlassCard(
          child: Row(
            children: [
              MiniPill(label: 'Recurring'),
              SizedBox(width: 8),
              MiniPill(label: '12', icon: Icons.receipt_long_rounded),
              SizedBox(width: 8),
              CountBadge(count: 3, semanticsLabel: 'filters active'),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const AppChip(label: 'All'),
            AppChip(label: 'Active', selected: true, color: cs.tertiary),
            const AppChip(label: 'Completed', icon: Icons.check_rounded),
          ],
        ),
        MetricGrid(
          tiles: [
            MetricCard(
              label: 'Workouts',
              value: '48',
              accent: sem.gym.base,
            ),
            MetricCard(
              label: 'Per week',
              value: '3.2',
              accent: sem.gym.base,
            ),
            MetricCard(
              label: 'Week streak',
              value: '12w',
              accent: sem.warning.base,
            ),
            MetricCard(
              label: 'Last workout',
              value: 'Today',
              accent: sem.tasks.base,
            ),
          ],
        ),
        InsightsCard(
          icon: Icons.bar_chart_rounded,
          color: sem.gym.base,
          title: 'Workouts over time',
          subtitle: '48 sessions across 31 days',
          takeaway:
              'Busiest stretch was the week of 4 August, with 5 sessions.',
          child: const SizedBox(height: 40),
        ),
        Row(
          children: [
            Expanded(
              child: AppStepper(controller: _reps, label: 'Reps'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppStepper(
                controller: _weight,
                label: 'Weight',
                decimal: true,
                step: 2.5,
              ),
            ),
          ],
        ),
        const StaggeredEntry(
          index: 2,
          child: Text('A staggered row of body text that should not clip'),
        ),
        const PrimaryButton(label: 'Save measurement entry', expand: true),
        const SecondaryButton(label: 'Manage measurement types', expand: true),
        const AppLoading(message: 'Loading your training history'),
        const AppEmptyState(
          icon: Icons.insights_rounded,
          title: 'Nothing to chart yet',
          message: 'Log a workout or record a measurement to see trends here.',
        ),
        const AppErrorView(error: 'Could not reach the database'),
      ],
    );
  }
}
