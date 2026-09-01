import 'package:flutter/material.dart';


/// Shows a modal bottom sheet on the **root** navigator.
///
/// [MainScaffold] (see `lib/shared/widgets/main_scaffold.dart`) sets
/// `extendBody: true` with a translucent, blurred floating [NavigationBar]
/// as its `bottomNavigationBar`, and every shell route (Dashboard, Finance,
/// Tasks, Gym, Notes) lives inside a nested [Navigator] scoped to that
/// Scaffold's `body`. A [Scaffold] always paints `bottomNavigationBar`
/// *above* `body` in z-order — that's what makes the glass-blur effect
/// work — so a sheet opened on the nested (body-scoped) navigator is
/// visually covered by the floating nav bar at the bottom, no matter how
/// the sheet's own layout is structured. Routing the sheet through the
/// **root** navigator instead renders it above the entire [MainScaffold],
/// nav bar included, so its content (and actions) are never hidden.
///
/// Always call this instead of `showModalBottomSheet` directly so new
/// sheets don't regress into the same problem.

Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool? showDragHandle,
  bool useSafeArea = false,
  Color? backgroundColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor,
    builder: (ctx) => Builder(builder: builder),
  );
}
