import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/segmented_control.dart';
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
    final tt = Theme.of(context).textTheme;
    const accent = Color(0xFFEF4444);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TRAINING',
                          style: tt.labelSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Gym',
                          style: tt.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Gym mentor',
                    icon: const Icon(Icons.psychology_rounded),
                    onPressed: () => context.push('/mentor?kind=gym'),
                  ),
                ],
              ),
            ),
            SegmentedControl(
              labels: _labels,
              icons: _icons,
              index: _tabs.index,
              color: accent,
              onTap: (i) => _tabs.animateTo(i),
            ),
            const SizedBox(height: 4),
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
      ),
    );
  }
}
