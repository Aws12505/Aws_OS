import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  static const _labels = ['Measurements', 'Programs'];
  static const _icons = [
    Icons.straighten_rounded,
    Icons.list_alt_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TRAINING',
                      style: tt.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      )),
                  const SizedBox(height: 2),
                  Text('Gym',
                      style: tt.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      )),
                ],
              ),
            ),
            _GymSegmented(
              labels: _labels,
              icons: _icons,
              index: _tabs.index,
              accent: accent,
              onTap: (i) => _tabs.animateTo(i),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [
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

class _GymSegmented extends StatelessWidget {
  const _GymSegmented({
    required this.labels,
    required this.icons,
    required this.index,
    required this.accent,
    required this.onTap,
  });
  final List<String> labels;
  final List<IconData> icons;
  final int index;
  final Color accent;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == index ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: i == index
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icons[i],
                          size: 16,
                          color: i == index
                              ? Colors.white
                              : cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        labels[i],
                        style: tt.labelLarge?.copyWith(
                          color: i == index
                              ? Colors.white
                              : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
