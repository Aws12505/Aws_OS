import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/app_theme.dart';
import '../design/surface_scope.dart';

export 'section_header.dart' show SectionHeader;

/// The scaffold every screen uses.
///
/// Declares which of the two surface treatments the screen renders with, and
/// standardizes safe-area and system-bar handling so screens stop re-wiring the
/// same boilerplate.
///
/// [mode] is required rather than defaulted: making it a compile error forces
/// each screen to state the choice instead of silently inheriting one.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    required this.mode,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomSafeArea = false,
  });

  final Widget body;

  /// [SurfaceMode.ambient] lets the global aurora show through and renders
  /// cards frosted. [SurfaceMode.working] paints an opaque canvas over it and
  /// renders cards flat.
  final SurfaceMode mode;

  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Whether to inset the bottom safe area. Off by default because most screens
  /// scroll under the translucent bottom nav.
  final bool bottomSafeArea;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SurfaceScope(
      mode: mode,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // The app draws edge to edge over a gradient and never set this, so
        // status-bar icons could vanish into the background at the light/dark
        // boundary.
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ),
        child: Scaffold(
          // Opaque on working screens. This hides the global aurora without
          // unmounting it, and it also stops the outgoing screen showing
          // through the incoming one during a push.
          backgroundColor: mode == SurfaceMode.working
              ? surfaces.canvas
              : Colors.transparent,
          appBar: appBar,
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: floatingActionButtonLocation,
          body: SafeArea(bottom: bottomSafeArea, child: body),
        ),
      ),
    );
  }
}

/// Paints the opaque working canvas and scopes its subtree.
///
/// For a working tab inside an ambient host: the host keeps a transparent
/// scaffold so the aurora shows through on its expressive tabs, and each dense
/// tab covers it here instead.
class WorkingSurface extends StatelessWidget {
  const WorkingSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SurfaceScope(
      mode: SurfaceMode.working,
      child: ColoredBox(color: context.surfaces.canvas, child: child),
    );
  }
}

/// Scopes a subtree back to the ambient treatment, letting the global aurora
/// show through. The inverse of [WorkingSurface], for an expressive tab inside
/// a working host.
class AmbientSurface extends StatelessWidget {
  const AmbientSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SurfaceScope(mode: SurfaceMode.ambient, child: child);
  }
}
