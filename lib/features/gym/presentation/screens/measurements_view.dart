import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/tokens.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/sparkline.dart';
import '../providers.dart';

class MeasurementsView extends ConsumerWidget {
  const MeasurementsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(measurementTypesStreamProvider);
    final entriesAsync = ref.watch(measurementEntriesStreamProvider);
    final valuesAsync = ref.watch(measurementValuesStreamProvider);

    return Scaffold(
      body: typesAsync.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppErrorView(error: e),
        data: (types) {
          if (types.isEmpty) {
            return AppEmptyState(
              icon: Icons.straighten_rounded,
              title: 'No measurement types',
              message: 'Add a few (Weight, Chest, …) before recording entries.',
              accent: DomainColors.gym,
              action: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: DomainColors.gym,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Manage types'),
                onPressed: () => _showTypesSheet(context),
              ),
            );
          }
          return entriesAsync.when(
            loading: () => const AppLoading(),
            error: (e, _) => AppErrorView(error: e),
            data: (entries) {
              final byEntry = <String, List<MeasurementValue>>{};
              for (final v
                  in (valuesAsync.value ?? const <MeasurementValue>[])) {
                byEntry.putIfAbsent(v.entryId, () => []).add(v);
              }
              final typesById = {for (final t in types) t.id: t};

              // Chronological value series per type (oldest → newest).
              final entriesAsc = entries.reversed.toList();
              final seriesByType = <String, List<double>>{};
              for (final e in entriesAsc) {
                for (final v in (byEntry[e.id] ?? const [])) {
                  seriesByType.putIfAbsent(v.typeId, () => []).add(v.value);
                }
              }
              final trendTypes =
                  types.where((t) => (seriesByType[t.id] ?? const []).isNotEmpty);

              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                children: [
                  _ManageTypesCard(onTap: () => _showTypesSheet(context)),
                  if (trendTypes.isNotEmpty) ...[
                    const _SectionLabel('Trends'),
                    SizedBox(
                      height: 152,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final t in trendTypes)
                            _TypeTrendCard(
                              type: t,
                              series: seriesByType[t.id]!,
                            ),
                        ],
                      ),
                    ),
                  ],
                  const _SectionLabel('History'),
                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: AppEmptyState(
                        compact: true,
                        icon: Icons.monitor_weight_outlined,
                        title: 'No entries yet',
                        message: 'Tap + to record your first measurement.',
                        accent: DomainColors.gym,
                      ),
                    ),
                  for (final e in entries)
                    _EntryTile(
                      entry: e,
                      values: byEntry[e.id] ?? const [],
                      typesById: typesById,
                      onDelete: () => ref.read(gymDaoProvider).deleteEntry(e.id),
                    ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: DomainColors.gym,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Entry'),
        onPressed: () {
          final types =
              ref.read(measurementTypesStreamProvider).value ?? const [];
          if (types.isEmpty) {
            _showTypesSheet(context);
          } else {
            _showEntrySheet(context);
          }
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: tt.labelMedium?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ManageTypesCard extends StatelessWidget {
  const _ManageTypesCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.72),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: DomainColors.gym.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.tune_rounded,
              color: DomainColors.gym, size: 18),
        ),
        title: const Text('Manage measurement types',
            style: TextStyle(fontWeight: FontWeight.w600)),
        trailing: Icon(Icons.chevron_right_rounded,
            color: cs.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}

class _TypeTrendCard extends StatelessWidget {
  const _TypeTrendCard({required this.type, required this.series});
  final MeasurementType type;
  final List<double> series;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final latest = series.last;
    final prev = series.length >= 2 ? series[series.length - 2] : null;
    final delta = prev == null ? null : latest - prev;
    final up = (delta ?? 0) > 0;
    final deltaColor = delta == null || delta == 0
        ? cs.onSurfaceVariant
        : (up ? DomainColors.income : DomainColors.expense);

    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.72),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(type.name,
              style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(_fmt(latest),
                      maxLines: 1,
                      style: tt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                ),
              ),
              const SizedBox(width: 3),
              Text(type.unit ?? '',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          if (delta != null && delta != 0)
            Row(
              children: [
                Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 12, color: deltaColor),
                Flexible(
                  child: Text('${_fmt(delta.abs())}${type.unit ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall?.copyWith(
                          color: deltaColor, fontWeight: FontWeight.w700)),
                ),
              ],
            )
          else
            Text('${series.length} record${series.length == 1 ? '' : 's'}',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          const Spacer(),
          Sparkline(values: series, color: DomainColors.gym, fill: true),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.values,
    required this.typesById,
    required this.onDelete,
  });
  final MeasurementEntry entry;
  final List<MeasurementValue> values;
  final Map<String, MeasurementType> typesById;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.72),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DomainColors.gym.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.monitor_weight_rounded,
                  color: DomainColors.gym, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat.yMMMd().format(entry.takenAt),
                      style: tt.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final v in values)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${typesById[v.typeId]?.name ?? '?'}: ${v.value}${typesById[v.typeId]?.unit ?? ''}',
                            style: tt.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  size: 18, color: cs.error),
              onPressed: onDelete,
              style: IconButton.styleFrom(
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showTypesSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: const _TypesSheet(),
    ),
  );
}

void _showEntrySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: const _EntrySheet(),
    ),
  );
}

class _TypesSheet extends ConsumerWidget {
  const _TypesSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(measurementTypesStreamProvider).value ??
        const <MeasurementType>[];
    final controller = TextEditingController();
    final unitController = TextEditingController();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Measurement types',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final t in types)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(t.name),
              subtitle: t.unit == null ? null : Text(t.unit!),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    ref.read(gymDaoProvider).deleteMeasurementType(t.id),
              ),
            ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                      labelText: 'Name', hintText: 'Weight, Chest, …'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: unitController,
                  decoration: const InputDecoration(
                      labelText: 'Unit', hintText: 'kg, cm'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle),
                onPressed: () async {
                  final n = controller.text.trim();
                  if (n.isEmpty) return;
                  await ref.read(gymDaoProvider).upsertMeasurementType(
                        MeasurementTypesCompanion.insert(
                          name: n,
                          unit: Value(unitController.text.trim().isEmpty
                              ? null
                              : unitController.text.trim()),
                        ),
                      );
                  controller.clear();
                  unitController.clear();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntrySheet extends ConsumerStatefulWidget {
  const _EntrySheet();
  @override
  ConsumerState<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<_EntrySheet> {
  DateTime _date = DateTime.now();
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String typeId) =>
      _controllers.putIfAbsent(typeId, () => TextEditingController());

  Future<void> _save(List<MeasurementType> types) async {
    final values = <String, double>{};
    for (final t in types) {
      final raw = _controllers[t.id]?.text.trim();
      if (raw == null || raw.isEmpty) continue;
      final v = double.tryParse(raw.replaceAll(',', '.'));
      if (v == null) continue;
      values[t.id] = v;
    }
    if (values.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Fill at least one value.'),
      ));
      return;
    }
    await ref.read(gymDaoProvider).insertEntryReturning(
          takenAt: _date,
          values: values,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(measurementTypesStreamProvider).value ??
        const <MeasurementType>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New measurement entry',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(DateFormat.yMMMd().format(_date)),
              trailing: const Icon(Icons.event),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 8),
            for (final t in types)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: TextField(
                  controller: _controllerFor(t.id),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: t.name,
                    suffixText: t.unit ?? '',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _save(types),
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
