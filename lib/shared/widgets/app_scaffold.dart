import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/app_theme.dart';

export 'section_header.dart' show SectionHeader, SectionLabel;

/// The scaffold every screen uses.
///
/// There used to be two surface treatments here and a required `mode` to pick
/// between them: an ambient one that let a gradient backdrop show through
/// frosted cards, and a working one that painted over it. There is one
/// treatment now. Every screen is an opaque page, and the parameter, the
/// `SurfaceScope` that published it and the backdrop it selected are all gone.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomSafeArea = false,
    this.backgroundColor,
  });

  final Widget body;

  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Whether to inset the bottom safe area. Off by default because most screens
  /// scroll under the bottom nav.
  final bool bottomSafeArea;

  /// Overrides the page fill. Almost nothing should: a page that is not the
  /// canvas colour is a page that has left the design.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The app draws edge to edge and never set this, so status-bar icons
      // could vanish into the background at the light/dark boundary.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        // Opaque, always. This is also what stops the outgoing screen showing
        // through the incoming one during a push.
        backgroundColor: backgroundColor ?? surfaces.canvas,
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        body: SafeArea(bottom: bottomSafeArea, child: body),
      ),
    );
  }
}
