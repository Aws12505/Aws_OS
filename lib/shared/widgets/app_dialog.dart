import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/app_theme.dart';

/// The app's confirmation dialog.
///
/// Replaces thirty-odd hand-rolled `AlertDialog`s that each phrased their
/// buttons differently and styled destructive actions inconsistently, or not at
/// all. Returns false when dismissed, so a barrier tap is never mistaken for a
/// yes.
///
/// Use this for anything that cascades or cannot be undone. For a single,
/// frequent, reversible delete, prefer [showUndoSnackBar]: an undo window
/// interrupts less than a dialog and protects just as well.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          if (destructive)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ctx.sem.expense.base,
                foregroundColor: ctx.sem.expense.onContainer,
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(ctx).pop(true);
              },
              child: Text(confirmLabel),
            )
          else
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmLabel),
            ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Confirms a completed action and offers to take it back.
///
/// The app used to delete days, exercises, supersets, sessions, measurement
/// entries and measurement types instantly with neither a confirmation nor a
/// way back. For frequent single deletes this is the better answer: the common
/// case stays one tap, and the mistake stays recoverable.
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: 'Undo', onPressed: onUndo),
      ),
    );
}

/// Generic dialog host for the cases that need real content rather than a
/// yes/no: a text field, a picker, a form.
///
/// Exists so those still get the app's dialog theme and its confirm/cancel
/// ordering rather than each call site rebuilding an `AlertDialog`.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => Builder(builder: builder),
  );
}
