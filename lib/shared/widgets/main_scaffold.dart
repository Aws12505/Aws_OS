import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../design/app_theme.dart';
import 'quick_action_fab.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  static const _destinations = <_NavDestination>[
    _NavDestination(
      '/',
      Icons.dashboard_outlined,
      Icons.dashboard_rounded,
      'Home',
    ),
    _NavDestination(
      '/finance',
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
      'Finance',
    ),
    _NavDestination(
      '/tasks',
      Icons.checklist_outlined,
      Icons.checklist_rounded,
      'Tasks',
    ),
    _NavDestination(
      '/gym',
      Icons.fitness_center_outlined,
      Icons.fitness_center_rounded,
      'Gym',
    ),
    _NavDestination(
      '/notes',
      Icons.sticky_note_2_outlined,
      Icons.sticky_note_2_rounded,
      'Notes',
    ),
    _NavDestination(
      '/sharing',
      Icons.share_outlined,
      Icons.share_rounded,
      'Share',
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

  @override
  Widget build(BuildContext context) {
    final index = _indexFor(location);
    final surfaces = context.surfaces;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: child,
      floatingActionButton: const QuickActionFab(),
      bottomNavigationBar: ClipRect(
        // ClipRect, not ClipRRect: the bar is square-edged, and the clip is
        // here only to bound the blur to the bar's own rectangle.
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surfaces.navFill,
              border: Border(
                top: BorderSide(color: surfaces.navBorder, width: 1),
              ),
            ),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) {
                if (i == index) return;
                HapticFeedback.selectionClick();
                context.go(_destinations[i].route);
              },
              backgroundColor: Colors.transparent,
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                    tooltip: d.label,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination(
    this.route,
    this.icon,
    this.selectedIcon,
    this.label,
  );
  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
