import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/segmented_control.dart';
import '../../data/models/connection_mode.dart';
import '../../data/models/transfer_task.dart';
import '../providers.dart';
import '../save_location.dart';
import 'received_files_list.dart';
import 'transfer_progress.dart';

class ReceivePanel extends ConsumerStatefulWidget {
  const ReceivePanel({super.key});
  @override
  ConsumerState<ReceivePanel> createState() => _ReceivePanelState();
}

class _ReceivePanelState extends ConsumerState<ReceivePanel> {
  ConnectionMode _mode = ConnectionMode.lan;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(shareSessionProvider);
    final controller = ref.read(shareSessionProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Refresh the received-files list whenever a task finishes landing a file.
    ref.listen<int>(
      shareSessionProvider.select(
        (v) => v.tasks
            .where((t) => t.status == TransferStatus.done)
            .length,
      ),
      (prev, next) {
        if (next != (prev ?? 0)) ref.invalidate(receivedFilesListProvider);
      },
    );

    // Surface failures (e.g. "Start receiving" couldn't bind a server) instead
    // of leaving the screen looking unchanged with no explanation.
    ref.listen<String?>(shareSessionProvider.select((v) => v.error), (
      prev,
      next,
    ) {
      if (next != null && next != prev) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next)));
      }
    });

    if (!s.serverRunning) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, AppInsets.listBottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_tethering_rounded, size: 64, color: cs.primary),
              const SizedBox(height: 16),
              Text(
                'Receive files',
                style: tt.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how to connect, start receiving, then scan the code on '
                'the sending phone (or pick this device in its list).',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              SegmentedControl(
                margin: EdgeInsets.zero,
                labels: const ['Wi-Fi / LAN', 'Wi-Fi Direct'],
                icons: const [Icons.wifi_rounded, Icons.bolt_rounded],
                index: _mode == ConnectionMode.wifiDirect ? 1 : 0,
                onTap: (i) => setState(
                  () => _mode = i == 1
                      ? ConnectionMode.wifiDirect
                      : ConnectionMode.lan,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _mode == ConnectionMode.wifiDirect
                    ? 'Creates a direct link with no router or internet. Fastest offline.'
                    : 'Both phones on the same Wi-Fi. Fast and zero setup.',
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Start receiving',
                icon: Icons.download_rounded,
                expand: true,
                onPressed: () async {
                  await [
                    Permission.nearbyWifiDevices,
                    Permission.locationWhenInUse,
                  ].request();
                  await controller.startReceiving(mode: _mode);
                },
              ),
              const SizedBox(height: 20),
              const _SaveLocationCard(),
              const SizedBox(height: 12),
              const ReceivedFilesCard(),
            ],
          ),
        ),
      );
    }

    final qr = controller.qrData;
    final wd = controller.wdGroup;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, AppInsets.listBottom),
      children: [
        if (wd != null)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Wi-Fi Direct link',
                      style: tt.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'On the other phone, join this Wi-Fi first, then scan the code:',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                _CredRow(label: 'Network', value: wd.ssid),
                _CredRow(label: 'Password', value: wd.pass),
              ],
            ),
          ),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready to receive',
                style: tt.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                s.status ?? 'Waiting for a sender…',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              if (qr != null && qr.isNotEmpty)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    // Literally white on purpose: a QR code has to be dark on
                    // light for scanners to read it, in either theme.
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: QrImageView(
                      data: qr,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const TransferProgressCard(),
        const _SaveLocationCard(),
        const ReceivedFilesCard(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SecondaryButton(
            label: 'Stop receiving',
            icon: Icons.stop_rounded,
            expand: true,
            onPressed: controller.stopReceiving,
          ),
        ),
      ],
    );
  }
}

/// Shows where received files are saved and lets the user pick a folder.
class _SaveLocationCard extends ConsumerWidget {
  const _SaveLocationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pathAsync = ref.watch(saveDirectoryProvider);
    final custom = ref.watch(shareSettingsStoreProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Save location',
                style: tt.titleSmall?.weight(FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          pathAsync.when(
            data: (path) => Text(
              path,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            loading: () => Text(
              'Loading…',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            error: (_, _) => Text(
              'Default folder',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Change folder',
                  icon: Icons.drive_folder_upload_rounded,
                  expand: true,
                  onPressed: () => pickShareSaveDirectory(context, ref),
                ),
              ),
              FutureBuilder<String?>(
                future: custom.saveDirectory(),
                builder: (_, snap) => snap.data == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: IconButton(
                          tooltip: 'Reset to default',
                          icon: const Icon(Icons.restore_rounded),
                          onPressed: () => resetShareSaveDirectory(ref),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CredRow extends StatelessWidget {
  const _CredRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: tt.bodyMedium?.weight(FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () => Clipboard.setData(ClipboardData(text: value)),
          ),
        ],
      ),
    );
  }
}
