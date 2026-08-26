import 'dart:async';

import 'package:flutter/material.dart';

import '../design/app_theme.dart';

/// Fades and lifts a list item into place, once.
///
/// The stagger is deliberately bounded and one-shot. It exists to make a list
/// arriving from the database read as *arriving* rather than blinking into
/// existence, which is the only thing it communicates. Replaying it on every
/// rebuild would turn a scroll into a light show, and delaying the twentieth
/// row by two seconds would be worse than no animation, so the delay caps out
/// after a handful of items.
///
/// Collapses to nothing under reduced motion, because the durations come from
/// the motion tokens and those go to zero.
class StaggeredEntry extends StatefulWidget {
  const StaggeredEntry({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  /// Beyond this position the delay stops growing. Rows further down are
  /// almost certainly below the fold anyway.
  static const int _maxStaggered = 8;

  @override
  State<StaggeredEntry> createState() => _StaggeredEntryState();
}

class _StaggeredEntryState extends State<StaggeredEntry>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Timer? _start;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;

    final motion = context.motion;
    final controller = AnimationController(
      vsync: this,
      duration: motion.short,
    );
    _controller = controller;

    if (motion.scale == 0) {
      controller.value = 1;
      return;
    }
    final steps = widget.index.clamp(0, StaggeredEntry._maxStaggered);
    if (steps == 0) {
      controller.forward();
      return;
    }
    // A cancellable timer, not a bare `Future.delayed`: scrolling a long list
    // disposes rows constantly, and an uncancelled delay would keep firing
    // into dead state.
    _start = Timer(Duration(milliseconds: 30 * steps), controller.forward);
  }

  @override
  void dispose() {
    _start?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.child;
    final curved = CurvedAnimation(
      parent: controller,
      curve: context.motion.enter,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}
