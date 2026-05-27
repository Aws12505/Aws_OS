import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  static const _destinations = <_NavDestination>[
    _NavDestination('/', Icons.dashboard_rounded, 'Home'),
    _NavDestination('/finance', Icons.account_balance_wallet_rounded, 'Finance'),
    _NavDestination('/tasks', Icons.checklist_rounded, 'Tasks'),
    _NavDestination('/gym', Icons.fitness_center_rounded, 'Gym'),
    _NavDestination('/notes', Icons.notes_rounded, 'Notes'),
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
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_destinations[i].route),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination(this.route, this.icon, this.label);
  final String route;
  final IconData icon;
  final String label;
}
