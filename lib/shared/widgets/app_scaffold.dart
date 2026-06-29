import 'package:flutter/material.dart';

import 'glass.dart';

/// Thin convenience over [Scaffold] for inner screens.
///
/// The app paints a single global [AuroraBackground] behind every route (see
/// `app/app.dart`) and the theme makes scaffolds transparent, so this
/// intentionally does NOT add a background — it only standardizes app bar +
/// safe-area handling so screens stop re-wiring the same boilerplate.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomSafeArea = false,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Whether to inset the bottom safe area. Off by default because most screens
  /// scroll under the translucent bottom nav.
  final bool bottomSafeArea;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: SafeArea(bottom: bottomSafeArea, child: body),
    );
  }
}

/// Magazine-style header (small kicker + large title + optional trailing).
/// A thin, semantically-named alias over [EditorialHeader] so feature screens
/// stop hand-rolling the kicker/title column.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.kicker,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 16, 4),
  });

  final String kicker;
  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return EditorialHeader(
      kicker: kicker,
      title: title,
      trailing: trailing,
      padding: padding,
    );
  }
}
