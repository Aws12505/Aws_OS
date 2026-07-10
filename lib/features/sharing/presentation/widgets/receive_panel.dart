import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../shared/design/tokens.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/segmented_control.dart';
import '../../data/models/connection_mode.dart';
import '../providers.dart';
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

    if (!s.serverRunning) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_tethering_rounded, size: 64, color: cs.primary),
              const SizedBox(height: 16),
              Text(
                'Receive files',
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
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
                    ? 'Creates a direct link with no router or internet — fastest offline.'
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
            ],
          ),
        ),
      );
    }

    final qr = controller.qrData;
    final wd = controller.wdGroup;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
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
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () => Clipboard.setData(ClipboardData(text: value)),
          ),
        ],
      ),
    );
  }
}
