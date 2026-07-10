import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    showDialog<void>(
      context: context,
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
    return AppScaffold(
      body: Column(
        children: [
          const SectionHeader(kicker: 'Transfer', title: 'Local sharing'),
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
