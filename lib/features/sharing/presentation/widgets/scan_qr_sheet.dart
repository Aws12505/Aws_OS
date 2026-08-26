import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../data/models/connection_mode.dart';
import '../../data/models/share_device.dart';
import '../../data/wire/share_protocol.dart';

/// Opens the camera to scan a peer's pairing QR; returns the resolved
/// [ShareDevice] (with its token) or null if cancelled.
Future<ShareDevice?> showScanQrSheet(BuildContext context) {
  return showAppModalBottomSheet<ShareDevice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ScanSheet(),
  );
}

class _ScanSheet extends StatefulWidget {
  const _ScanSheet();
  @override
  State<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<_ScanSheet> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Permission.camera.request();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_handled) return;
    for (final b in cap.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final info = ShareProtocol.parsePairing(raw);
      if (info != null) {
        _handled = true;
        Navigator.of(context).pop(
          ShareDevice(
            id: info.name,
            name: info.name,
            host: info.ip,
            port: info.port,
            token: info.token,
            mode: ConnectionModeX.fromWire(info.mode),
            joinSsid: info.ssid,
            joinPass: info.pass,
          ),
        );
        return;
      }
    }
    if (mounted) setState(() => _error = 'Not an Aws OS share code');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan the QR on the other phone',
              style: tt.titleMedium,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: SizedBox(
                height: 320,
                width: double.infinity,
                child: MobileScanner(controller: _controller, onDetect: _onDetect),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: cs.error)),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
