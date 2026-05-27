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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gym'),
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: 'Measurements'),
          Tab(text: 'Programs'),
        ]),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          MeasurementsView(),
          ProgramsView(),
        ],
      ),
    );
  }
}
