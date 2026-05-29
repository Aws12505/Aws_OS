import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: isDark ? 0.6 : 0.78),
              border: Border(
                top: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
            ),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => context.go(_destinations[i].route),
              backgroundColor: Colors.transparent,
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
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
