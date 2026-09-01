import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/segmented_control.dart';
import '../../../mentor/data/forecast_service.dart';
import '../../../mentor/presentation/mentor_providers.dart';
import '../gym_insights_view.dart';
import 'measurements_view.dart';
import 'programs_view.dart';

class GymScreen extends ConsumerStatefulWidget {
  const GymScreen({super.key});

  @override
  ConsumerState<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends ConsumerState<GymScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  static const _labels = ['Insights', 'Measurements', 'Programs'];
  static const _icons = [
    Icons.insights_rounded,
    Icons.straighten_rounded,
    Icons.list_alt_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.sem.gym;
    final forecast = ref.watch(gymForecastProvider).valueOrNull;

    // Ambient host: the aurora shows through on Insights. The two dense tabs
    // cover it with their own working canvas.
    return AppScaffold(
      body: Column(
        children: [
          SectionHeader(
            title: 'Gym',
            status: _trainingStatus(forecast),
            statusIcon: Icons.bolt_rounded,
            statusColor: _statusIsWarm(forecast) ? accent.fg : null,
            trailing: IconButton.filledTonal(
              tooltip: 'Gym mentor',
              icon: const Icon(Icons.psychology_rounded),
              onPressed: () => context.push('/mentor?kind=gym'),
            ),
          ),
          SegmentedControl(
            labels: _labels,
            icons: _icons,
            index: _tabs.index,
            color: accent.base,
            onTap: (i) => _tabs.animateTo(i),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                GymInsightsView(),
                MeasurementsView(),
                ProgramsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the training week looks like right now.
///
/// This line replaces the uppercase 'TRAINING' kicker, which only repeated the
/// Gym label the user had just tapped in the nav bar.
String? _trainingStatus(GymForecast? f) {
  if (f == null) return null;
  if (!f.hasData) return 'No sessions logged yet';

  final days = f.lastSessionDaysAgo;
  final last = switch (days) {
    null => 'No sessions yet',
    0 => 'Trained today',
    1 => 'Trained yesterday',
    final d => 'Last session $d days ago',
  };
  if (f.currentWeekStreak > 1) {
    return '$last, ${f.currentWeekStreak} week streak';
  }
  return last;
}

/// Tints the status only when it is worth noticing: trained today, or a streak
/// worth keeping. Neutral information stays neutral.
bool _statusIsWarm(GymForecast? f) =>
    f != null && f.hasData && (f.lastSessionDaysAgo == 0 || f.currentWeekStreak > 1);
