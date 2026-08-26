import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design/app_theme.dart';
import '../../../shared/design/surface_scope.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/segmented_control.dart';
import '../data/models/share_session.dart';
import '../data/share_format.dart';
import 'providers.dart';
import 'widgets/receive_panel.dart';
import 'widgets/send_panel.dart';

/// The Local sharing screen — a Send / Receive toggle over the transport,
/// discovery and pairing services.
class SharingScreen extends ConsumerStatefulWidget {
  const SharingScreen({super.key});
  @override
  ConsumerState<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends ConsumerState<SharingScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startBrowse());
  }

  Future<void> _startBrowse() async {
    try {
      final id = await ref.read(shareIdentityProvider.future);
      await ref.read(discoveryServiceProvider).startBrowse(selfId: id.id);
    } catch (_) {}
  }

  @override
  void dispose() {
    ref.read(discoveryServiceProvider).stopBrowse();
    super.dispose();
  }

  void _showAccept(IncomingRequest req) {
    final controller = ref.read(shareSessionProvider.notifier);
    showAppDialog<void>(
      context,
      barrierDismissible: false,
      builder: (dCtx) => AlertDialog(
        title: const Text('Incoming files'),
        content: Text(
          '${req.senderName} wants to send ${req.fileCount} item(s) '
          '(${formatBytes(req.totalBytes)}). Accept?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dCtx);
              controller.respondToIncoming(false);
            },
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dCtx);
              controller.respondToIncoming(true);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<IncomingRequest?>(
      shareSessionProvider.select((s) => s.incoming),
      (prev, next) {
        if (next != null) _showAccept(next);
      },
    );
    final session = ref.watch(shareSessionProvider);

    return AppScaffold(
      mode: SurfaceMode.working,
      body: Column(
        children: [
          SectionHeader(
            title: 'Local sharing',
            status: _statusLine(session),
            statusIcon: Icons.wifi_tethering_rounded,
            statusColor: session.active
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          // Same header-progress treatment the workout screen and the budget
          // bars use: if something is in flight, say how far along it is where
          // the eye already is.
          if (session.active)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, AppSpacing.sm),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: session.progress.clamp(0.0, 1.0)),
                  duration: context.motion.medium,
                  curve: context.motion.standardCurve,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    backgroundColor: context.surfaces.sunken,
                  ),
                ),
              ),
            ),
          SegmentedControl(
            labels: const ['Send', 'Receive'],
            icons: const [Icons.upload_rounded, Icons.download_rounded],
            index: _tab,
            onTap: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 4),
          Expanded(child: _tab == 0 ? const SendPanel() : const ReceivePanel()),
        ],
      ),
    );
  }
}

/// One line saying what the transfer is doing right now, or what to do next.
String _statusLine(ShareSession session) {
  if (session.active) {
    final percent = (session.progress * 100).round();
    final peer = session.peer?.name;
    final direction = session.role == ShareRole.sending ? 'Sending' : 'Receiving';
    final preposition = session.role == ShareRole.sending ? 'to' : 'from';
    return peer == null
        ? '$direction $percent%'
        : '$direction $preposition $peer, $percent%';
  }
  if (session.done) return 'Transfer finished';
  if (session.serverRunning) return 'Ready to receive';
  return 'Pick files to send, or start receiving';
}
