import 'package:flutter/widgets.dart';

/// Which of the two surface treatments a subtree renders with.
enum SurfaceMode {
  /// Aurora visible, frosted translucent cards. Reading-and-reflecting screens:
  /// the dashboard overview, the three insights views, mentor, debrief, lock.
  ambient,

  /// Opaque layered surfaces, hairline dividers, no blur. Screens where density
  /// and legibility win: every list, every detail screen, every form sheet,
  /// settings.
  working,
}

/// Explicit override on a single surface, bypassing the ambient scope.
enum SurfaceVariant { auto, glass, flat }

/// Publishes the surface mode to descendants.
///
/// This is an `InheritedWidget` rather than a nested `Theme` for a specific
/// reason: `showAppModalBottomSheet` forces `useRootNavigator: true` so sheets
/// clear the blurred nav bar, and a root-navigator overlay is not a descendant
/// of a screen-local `Theme`. Every form sheet would silently fall back to the
/// root theme's mode. The same applies to `showDialog`. Sheets and dialogs
/// therefore state their variant explicitly.
class SurfaceScope extends InheritedWidget {
  const SurfaceScope({super.key, required this.mode, required super.child});

  final SurfaceMode mode;

  /// Defaults to [SurfaceMode.working]. Anything that escapes a scope — a
  /// root-navigator sheet, a dialog, an imperatively pushed detail, a widget
  /// test — renders flat and legible. Fail safe toward legibility.
  static SurfaceMode of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SurfaceScope>()?.mode ??
      SurfaceMode.working;

  @override
  bool updateShouldNotify(SurfaceScope oldWidget) => oldWidget.mode != mode;
}
