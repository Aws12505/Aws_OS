import 'package:flutter/material.dart';

import '../design/app_theme.dart';

/// One bottom-nav destination, without knowing what selecting it does.
@immutable
class NavItem {
  const NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The app's bottom navigation bar.
///
/// Split out of `MainScaffold` so the chrome is separable from the routing it
/// drives, and so it can be rendered on its own.
///
/// Opaque, with a rule on top. It used to run a full-width backdrop blur on
/// every frame of every screen — a real cost on a low-end device, for an effect
/// this design no longer uses — and the selected destination sat in a filled
/// pill. The label and icon change colour and weight instead, which leaves the
/// bar reading as a row of words rather than a row of buttons.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.navFill,
        border: Border(
          top: BorderSide(
            color: surfaces.navBorder,
            width: AppSurfaces.hairlineWidth,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        backgroundColor: Colors.transparent,
        destinations: [
          for (final d in items)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
              tooltip: d.label,
            ),
        ],
      ),
    );
  }
}
