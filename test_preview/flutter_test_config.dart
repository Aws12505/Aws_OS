import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Applies to every test in this directory tree.
///
/// Tests must never reach the network for a font: it makes them slow, flaky
/// offline, and noisy (the package logs a warning per missing family). Widget
/// tests then typeset in the bundled Ahem font, which is what we want for
/// deterministic layout assertions.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
