import 'package:flutter/widgets.dart';

/// The `Navigator` inside the bottom-nav shell.
///
/// Detail screens are pushed imperatively onto this navigator so they can share
/// a `Hero` with the tile that opened them. That push sits *above* the shell's
/// page-based route, which means `context.go` swaps the page underneath it and
/// nothing appears to happen: from a program detail, tapping "Finance" used to
/// leave you looking at the same program until you had pressed back out of
/// every pushed screen.
///
/// The nav bar is built above this navigator, so `Navigator.of` there resolves
/// to the root one. Holding the key is what lets the bar unwind the shell stack
/// before it switches tab.
final shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellNavigator',
);

/// How many routes are stacked on top of the current tab.
///
/// Zero means the tab itself is showing. Anything higher means a detail screen
/// is open over it, which is what the shell chrome needs to know: the global
/// quick-add button belongs to a tab, and leaving it floating over a detail
/// screen put two unrelated action buttons in the same corner.
final shellDepth = ValueNotifier<int>(0);

/// Keeps [shellDepth] in step with the shell navigator's stack.
class ShellDepthObserver extends NavigatorObserver {
  void _sync(int delta) => shellDepth.value = (shellDepth.value + delta)
      .clamp(0, 1 << 20);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // The tab's own page-based route is the stack, not something on it.
    if (previousRoute != null) _sync(1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync(-1);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _sync(-1);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {}
}
