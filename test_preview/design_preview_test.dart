import 'package:aws_os/app/theme.dart';
import 'package:aws_os/shared/design/app_theme.dart';
import 'package:aws_os/shared/widgets/app_buttons.dart';
import 'package:aws_os/shared/widgets/app_card.dart';
import 'package:aws_os/shared/widgets/app_chip.dart';
import 'package:aws_os/shared/widgets/app_nav_bar.dart';
import 'package:aws_os/shared/widgets/app_stepper.dart';
import 'package:aws_os/shared/widgets/insights_card.dart';
import 'package:aws_os/shared/widgets/metric_grid.dart';
import 'package:aws_os/shared/widgets/pills.dart';
import 'package:aws_os/shared/widgets/section_header.dart';
import 'package:aws_os/shared/widgets/segmented_control.dart';
import 'package:aws_os/shared/widgets/stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the design language to PNGs so it can be looked at.
///
/// Lives outside `test/` on purpose. `flutter test` with no arguments only
/// scans `test/`, so these goldens never run as a regression gate — they are
/// font- and platform-dependent and would churn. Render them deliberately:
///
///     flutter test test_preview --update-goldens
///
/// The point is that a design pass which cannot be run on a device is
/// otherwise being written blind.
void main() {
  // Without this the whole render typesets in Ahem and every glyph is a black
  // box, which defeats the point of looking at it.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final weight in const [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      final data = await rootBundle.load('assets/fonts/Inter-$weight.ttf');
      // google_fonts points fontFamily at a weight-specific variant name, so
      // each file has to be registered under the family it will be asked for.
      final numeric = const {
        'Regular': 400,
        'Medium': 500,
        'SemiBold': 600,
        'Bold': 700,
        'ExtraBold': 800,
      }[weight];
      await (FontLoader('Inter_$numeric')..addFont(Future.value(data))).load();
      await (FontLoader('Inter')..addFont(Future.value(data))).load();
    }
  });

  for (final brightness in [Brightness.dark, Brightness.light]) {
    testWidgets('design language (${brightness.name})', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(ThemeSettings.defaults, brightness),
          home: const _Sheet(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await expectLater(
        find.byType(_Sheet),
        matchesGoldenFile('preview/design_${brightness.name}.png'),
      );
    });
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet();

  static final _reps = TextEditingController(text: '8');
  static final _weight = TextEditingController(text: '62.5');

  @override
  Widget build(BuildContext context) {
    final sem = context.sem;
    final surfaces = context.surfaces;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: surfaces.canvas,
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('Quick add'),
        onPressed: () {},
      ),
      bottomNavigationBar: AppNavBar(
        selectedIndex: 3,
        onSelected: (_) {},
        items: const [
          NavItem(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: 'Home',
          ),
          NavItem(
            icon: Icons.account_balance_wallet_outlined,
            selectedIcon: Icons.account_balance_wallet_rounded,
            label: 'Finance',
          ),
          NavItem(
            icon: Icons.checklist_outlined,
            selectedIcon: Icons.checklist_rounded,
            label: 'Tasks',
          ),
          NavItem(
            icon: Icons.fitness_center_outlined,
            selectedIcon: Icons.fitness_center_rounded,
            label: 'Gym',
          ),
          NavItem(
            icon: Icons.sticky_note_2_outlined,
            selectedIcon: Icons.sticky_note_2_rounded,
            label: 'Notes',
          ),
          NavItem(
            icon: Icons.share_outlined,
            selectedIcon: Icons.share_rounded,
            label: 'Share',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                title: 'Gym',
                status: 'Push day, 4 of 12 sets',
                statusIcon: Icons.bolt_rounded,
              ),
              SegmentedControl(
                labels: const ['Insights', 'Measurements', 'Programs'],
                index: 0,
                onTap: (_) {},
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionLabel('This month'),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            icon: Icons.trending_up_rounded,
                            color: sem.income.base,
                            label: 'Net',
                            value: '1,284,930',
                            sub: 'across 3 currencies',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatTile(
                            icon: Icons.fitness_center_rounded,
                            color: sem.gym.base,
                            label: 'Streak',
                            value: '12w',
                            sub: 'best this year',
                          ),
                        ),
                      ],
                    ),
                    const SectionLabel('Summary'),
                    MetricGrid(
                      tiles: [
                        MetricCard(
                          label: 'Workouts',
                          value: '48',
                          accent: sem.gym.base,
                        ),
                        const MetricCard(label: 'Per week', value: '3.2'),
                        MetricCard(
                          label: 'Streak',
                          value: '12w',
                          accent: sem.warning.base,
                        ),
                        const MetricCard(label: 'Last', value: 'Today'),
                      ],
                    ),
                    const SectionLabel('Filters'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const AppChip(label: 'All'),
                        AppChip(
                          label: 'Active',
                          selected: true,
                          color: sem.tasks.base,
                        ),
                        const AppChip(
                          label: 'Done',
                          icon: Icons.check_rounded,
                        ),
                        const MiniPill(label: 'Recurring'),
                      ],
                    ),
                  ],
                ),
              ),
              InsightsCard(
                icon: Icons.bar_chart_rounded,
                color: sem.gym.base,
                title: 'Workouts over time',
                subtitle: '48 sessions across 31 days',
                takeaway: 'Busiest stretch was the week of 4 August.',
                child: Container(
                  height: 90,
                  color: surfaces.sunken,
                ),
              ),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('A ruled section', style: tt.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'The default card: a rule, then content on the canvas.',
                      style: tt.bodySmall?.copyWith(
                        color: surfaces.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                style: CardStyle.block,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('A block', style: tt.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'For things that are objects: a program, an account.',
                      style: tt.bodySmall?.copyWith(
                        color: surfaces.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              RuledColumn(
                children: [
                  for (final row in const [
                    ('Bench press', '62.5 kg', '8'),
                    ('Incline dumbbell', '24.0 kg', '10'),
                    ('Cable fly', '15.0 kg', '12'),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(row.$1, style: tt.titleSmall),
                          ),
                          Text(row.$2, style: context.type.numeric),
                          const SizedBox(width: 12),
                          Text(
                            '× ${row.$3}',
                            style: context.type.numeric.copyWith(
                              color: surfaces.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppStepper(controller: _reps, label: 'Reps'),
                        ),
                        const SizedBox(width: 12),
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
                    const SizedBox(height: 16),
                    const TextField(
                      decoration: InputDecoration(
                        labelText: 'Note',
                        hintText: 'Felt strong today',
                      ),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(label: 'Log session', expand: true, onPressed: () {}),
                    const SizedBox(height: 8),
                    SecondaryButton(label: 'Manage days', expand: true, onPressed: () {}),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
