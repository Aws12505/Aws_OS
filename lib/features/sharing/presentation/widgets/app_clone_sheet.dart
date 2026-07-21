import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../../shared/widgets/app_buttons.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../data/models/share_item.dart';
import '../../data/services/installed_apps_service.dart';
import '../../data/share_format.dart';
import '../providers.dart';

const _uuid = Uuid();

/// Pick an installed app to send (APK + splits always; OBB / game data via
/// Shizuku when active). Returns the queued [ShareItem]s.
Future<List<ShareItem>?> showAppCloneSheet(BuildContext context) {
  return showAppModalBottomSheet<List<ShareItem>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _AppCloneSheet(),
  );
}

/// A rounded app launcher icon fetched lazily (and cached) from the platform.
/// Falls back to a generic glyph while loading or if none can be resolved.
class _AppIcon extends StatelessWidget {
  const _AppIcon({
    required this.package,
    required this.service,
    this.size = 40,
  });

  final String package;
  final InstalledAppsService service;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<Uint8List?>(
      future: service.icon(package),
      builder: (context, snap) {
        final radius = BorderRadius.circular(size * 0.22);
        final bytes = snap.data;
        if (bytes != null && bytes.isNotEmpty) {
          return ClipRRect(
            borderRadius: radius,
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
          );
        }
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: radius,
          ),
          child: Icon(
            Icons.android_rounded,
            size: size * 0.6,
            color: cs.onSurfaceVariant,
          ),
        );
      },
    );
  }
}

class _AppCloneSheet extends ConsumerStatefulWidget {
  const _AppCloneSheet();
  @override
  ConsumerState<_AppCloneSheet> createState() => _AppCloneSheetState();
}

class _AppCloneSheetState extends ConsumerState<_AppCloneSheet> {
  final _search = TextEditingController();
  String _query = '';
  List<InstalledApp>? _apps;
  bool _shizuku = false;

  InstalledApp? _selected;
  bool _obb = false;
  bool _data = false;
  int _obbSize = 0;
  int _dataSize = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final apps = await ref.read(installedAppsServiceProvider).list();
    final shizuku = await ref.read(shizukuServiceProvider).hasPermission();
    if (mounted) {
      setState(() {
        _apps = apps;
        _shizuku = shizuku;
      });
    }
  }

  Future<void> _select(InstalledApp app) async {
    setState(() {
      _selected = app;
      _obb = false;
      _data = false;
      _obbSize = 0;
      _dataSize = 0;
    });
    if (_shizuku) {
      final sz = ref.read(shizukuServiceProvider);
      final obb = await sz.dirSize('/sdcard/Android/obb/${app.package}');
      final data = await sz.dirSize('/sdcard/Android/data/${app.package}');
      if (mounted) {
        setState(() {
          _obbSize = obb;
          _dataSize = data;
        });
      }
    }
  }

  Future<void> _add() async {
    final app = _selected!;
    setState(() => _busy = true);
    final items = <ShareItem>[];
    try {
      final apks = await ref
          .read(installedAppsServiceProvider)
          .apkPaths(app.package);
      for (final path in apks) {
        items.add(
          ShareItem(
            id: _uuid.v4(),
            name: p.basename(path),
            size: _sizeOf(path),
            mime: 'application/vnd.android.package-archive',
            kind: ShareItemKind.apk,
            path: path,
            relPath: 'apk/${app.package}/${p.basename(path)}',
            packageId: app.package,
          ),
        );
      }
      if ((_obb || _data) && _shizuku) {
        final staging = await ref
            .read(receivedFilesStoreProvider)
            .appCloneStagingDir();
        final staged = await ref.read(shizukuServiceProvider).stage(
          package: app.package,
          obb: _obb,
          data: _data,
          stagingDir: staging.path,
        );
        for (final s in staged) {
          items.add(
            ShareItem(
              id: _uuid.v4(),
              name: p.basename(s.relPath),
              size: _sizeOf(s.path),
              kind: s.relPath.startsWith('obb/')
                  ? ShareItemKind.obb
                  : ShareItemKind.appData,
              path: s.path,
              relPath: s.relPath,
              packageId: app.package,
            ),
          );
        }
      }
    } catch (_) {}
    if (mounted) Navigator.of(context).pop(items);
  }

  int _sizeOf(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: _selected != null ? _detail(context) : _list(context),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final apps = _apps;
    final filtered = apps == null
        ? const <InstalledApp>[]
        : apps
              .where((a) => a.label.toLowerCase().contains(_query))
              .toList(growable: false);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Share an app',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            hintText: 'Search apps',
            isDense: true,
            prefixIcon: Icon(Icons.search_rounded, size: 20),
          ),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 8),
        if (apps == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          SizedBox(
            height: 380,
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final a = filtered[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _AppIcon(
                    package: a.package,
                    service: ref.read(installedAppsServiceProvider),
                  ),
                  title: Text(
                    a.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${formatBytes(a.apkSize)}${a.hasSplits ? ' · split APK' : ''}',
                  ),
                  onTap: () => _select(a),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _detail(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final app = _selected!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => setState(() => _selected = null),
            ),
            Expanded(
              child: Text(
                app.label,
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _AppIcon(
            package: app.package,
            service: ref.read(installedAppsServiceProvider),
            size: 44,
          ),
          title: const Text('APK'),
          subtitle: Text(
            '${formatBytes(app.apkSize)}'
            '${app.hasSplits ? ' · base + splits' : ''}',
          ),
          trailing: const Icon(Icons.check_circle_rounded, color: Colors.green),
        ),
        if (_shizuku) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _obb,
            onChanged: _obbSize > 0
                ? (v) => setState(() => _obb = v ?? false)
                : null,
            title: const Text('OBB expansion files'),
            subtitle: Text(
              _obbSize > 0 ? formatBytes(_obbSize) : 'None found',
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _data,
            onChanged: _dataSize > 0
                ? (v) => setState(() => _data = v ?? false)
                : null,
            title: const Text('Game data (Android/data)'),
            subtitle: Text(
              _dataSize > 0 ? formatBytes(_dataSize) : 'None found',
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Enable Shizuku to also include OBB and game data. '
              'APK sharing works without it.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Add to send',
          icon: Icons.add_rounded,
          expand: true,
          loading: _busy,
          onPressed: _busy ? null : _add,
        ),
      ],
    );
  }
}
