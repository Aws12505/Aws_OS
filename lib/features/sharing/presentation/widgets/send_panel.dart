import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../data/models/connection_mode.dart';
import '../../data/models/share_device.dart';
import '../../data/models/share_item.dart';
import '../../data/share_format.dart';
import '../providers.dart';
import 'app_clone_sheet.dart';
import 'payload_picker.dart';
import 'scan_qr_sheet.dart';
import 'transfer_progress.dart';
import '../../../../shared/widgets/app_card.dart';

class SendPanel extends ConsumerStatefulWidget {
  const SendPanel({super.key});
  @override
  ConsumerState<SendPanel> createState() => _SendPanelState();
}

class _SendPanelState extends ConsumerState<SendPanel> {
  final List<ShareItem> _items = [];
  bool _busy = false;

  int get _totalBytes => _items.fold(0, (s, i) => s + i.size);

  Future<void> _addFiles(FileType type) async {
    setState(() => _busy = true);
    try {
      final picked = await pickFilesToShare(type: type);
      setState(() => _items.addAll(picked));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addApps() async {
    final items = await showAppCloneSheet(context);
    if (items != null && items.isNotEmpty && mounted) {
      setState(() => _items.addAll(items));
    }
  }

  Future<void> _addBackup() async {
    setState(() => _busy = true);
    try {
      final item = await backupToShare(ref);
      setState(() => _items.add(item));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendTo(ShareDevice device) async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick something to send first')),
      );
      return;
    }
    if (device.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan the device QR to pair')),
      );
      return;
    }
    final needsJoin =
        (device.mode == ConnectionMode.wifiDirect ||
            device.mode == ConnectionMode.hotspot) &&
        device.joinSsid != null;
    if (needsJoin) {
      final joined = await _autoJoin(device);
      if (!joined) {
        final proceed = await _showJoinDialog(device);
        if (proceed != true) return;
      }
    }
    await ref.read(shareSessionProvider.notifier).sendTo(device, _items);
  }

  /// Tries to join the receiver's Wi-Fi Direct / hotspot network without
  /// leaving the app (Android 10+). Returns false on older Android or if the
  /// system declines — callers should fall back to the manual join dialog.
  Future<bool> _autoJoin(ShareDevice device) async {
    final ssid = device.joinSsid;
    if (ssid == null) return false;
    setState(() => _busy = true);
    try {
      await [
        Permission.nearbyWifiDevices,
        Permission.locationWhenInUse,
      ].request();
      return await ref
          .read(wifiConnectServiceProvider)
          .connect(ssid: ssid, password: device.joinPass);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _showJoinDialog(ShareDevice d) {
    return showAppConfirmDialog(
      context,
      title: 'Join the network',
      confirmLabel: 'Send',
      destructive: true,
    );
  }

  Future<void> _scanAndSend() async {
    final device = await showScanQrSheet(context);
    if (device != null && mounted) await _sendTo(device);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final devices = ref.watch(discoveredDevicesProvider).value ?? const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, AppInsets.listBottom),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What to send',
                style: tt.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PickChip(
                    icon: Icons.insert_drive_file_rounded,
                    label: 'Files',
                    onTap: _busy ? null : () => _addFiles(FileType.any),
                  ),
                  _PickChip(
                    icon: Icons.perm_media_rounded,
                    label: 'Photos & videos',
                    onTap: _busy ? null : () => _addFiles(FileType.media),
                  ),
                  _PickChip(
                    icon: Icons.android_rounded,
                    label: 'Apps',
                    onTap: _busy ? null : _addApps,
                  ),
                  _PickChip(
                    icon: Icons.backup_rounded,
                    label: 'App backup',
                    onTap: _busy ? null : _addBackup,
                  ),
                ],
              ),
              if (_items.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_items.length} item(s) · ${formatBytes(_totalBytes)}',
                        style: tt.bodyMedium?.weight(FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(_items.clear),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                for (final it in _items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(iconForKind(it.kind), size: 18, color: cs.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            it.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall,
                          ),
                        ),
                        Text(
                          formatBytes(it.size),
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send to',
                style: tt.titleMedium,
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Scan a QR code',
                icon: Icons.qr_code_scanner_rounded,
                expand: true,
                onPressed: _scanAndSend,
              ),
              const SizedBox(height: 12),
              Text(
                'Nearby devices',
                style: tt.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ).weight(FontWeight.w700),
              ),
              const SizedBox(height: 6),
              if (devices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No devices yet. Make sure the other phone tapped '
                    '“Receive”, or scan its QR.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                )
              else
                for (final d in devices)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.smartphone_rounded, color: cs.primary),
                    title: Text(d.name),
                    subtitle: Text('${d.host} · ${d.mode.label}'),
                    trailing: const Icon(Icons.send_rounded, size: 18),
                    onTap: () => _sendTo(d),
                  ),
            ],
          ),
        ),
        const TransferProgressCard(),
      ],
    );
  }
}

class _PickChip extends StatelessWidget {
  const _PickChip({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(icon, size: 18, color: cs.primary),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
