import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell_navigator.dart';
import '../design/app_theme.dart';
import 'app_nav_bar.dart';
import 'quick_action_fab.dart';

/// The shell around the six tabs: the nav bar, the quick-add button, and the
/// rule that switching tab always works.
class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  static const _destinations = <_NavDestination>[
    _NavDestination(
      '/',
      NavItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        label: 'Home',
      ),
    ),
    _NavDestination(
      '/finance',
      NavItem(
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet_rounded,
        label: 'Finance',
      ),
    ),
    _NavDestination(
      '/tasks',
      NavItem(
        icon: Icons.checklist_outlined,
        selectedIcon: Icons.checklist_rounded,
        label: 'Tasks',
      ),
    ),
    _NavDestination(
      '/gym',
      NavItem(
        icon: Icons.fitness_center_outlined,
        selectedIcon: Icons.fitness_center_rounded,
        label: 'Gym',
      ),
    ),
    _NavDestination(
      '/notes',
      NavItem(
        icon: Icons.sticky_note_2_outlined,
        selectedIcon: Icons.sticky_note_2_rounded,
        label: 'Notes',
      ),
    ),
    _NavDestination(
      '/sharing',
      NavItem(
        icon: Icons.share_outlined,
        selectedIcon: Icons.share_rounded,
        label: 'Share',
      ),
    ),
  ];

  int _indexFor(String loc) {
    for (var i = _destinations.length - 1; i >= 0; i--) {
      final route = _destinations[i].route;
      if (route == '/' ? loc == '/' : loc.startsWith(route)) {
        return i;
      }
    }
    return 0;
  }

  /// Switches tab, unwinding anything pushed on top of the current one first.
  ///
  /// Without the unwind the tap is swallowed: detail screens are pushed onto
  /// the shell navigator, so `go` replaces the page beneath them and the pushed
  /// screen stays on top. Tapping the tab you are already on unwinds without
  /// navigating, which is the usual way back to the top of a section.
  void _onDestinationSelected(BuildContext context, int i) {
    final index = _indexFor(location);
    final nav = shellNavigatorKey.currentState;
    final wasDeep = nav != null && nav.canPop();
    if (i == index && !wasDeep) return;

    HapticFeedback.selectionClick();
    if (wasDeep) nav.popUntil((route) => route.isFirst);
    if (i != index) context.go(_destinations[i].route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The bar is opaque now, so it takes its own space rather than having
      // content scroll under it.
      extendBody: false,
      backgroundColor: context.surfaces.canvas,
      body: child,
      // Hidden while a detail screen is open over the tab. Those screens have
      // their own actions, and two floating buttons in one corner is a choice
      // nobody wants to make.
      floatingActionButton: ValueListenableBuilder<int>(
        valueListenable: shellDepth,
        builder: (_, depth, _) =>
            depth == 0 ? const QuickActionFab() : const SizedBox.shrink(),
      ),
      bottomNavigationBar: AppNavBar(
        items: [for (final d in _destinations) d.item],
        selectedIndex: _indexFor(location),
        onSelected: (i) => _onDestinationSelected(context, i),
      ),
    );
  }
}

/// A nav item and the route it goes to.
class _NavDestination {
  const _NavDestination(this.route, this.item);
  final String route;
  final NavItem item;
}
