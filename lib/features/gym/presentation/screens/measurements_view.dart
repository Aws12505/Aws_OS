import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (types) {
          if (types.isEmpty) {
            return _EmptyState(
              title: 'No measurement types',
              message: 'Add a few (Weight, Chest, …) before recording entries.',
              actionLabel: 'Manage types',
              onPressed: () => _showTypesSheet(context),
            );
          }
          return entriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toString())),
            data: (entries) {
              final byEntry = <String, List<MeasurementValue>>{};
              for (final v in (valuesAsync.value ?? const <MeasurementValue>[])) {
                byEntry.putIfAbsent(v.entryId, () => []).add(v);
              }
              final typesById = {for (final t in types) t.id: t};
              return ListView(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                children: [
                  Card(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.tune_rounded,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            size: 18),
                      ),
                      title: const Text('Manage measurement types',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                      onTap: () => _showTypesSheet(context),
                    ),
                  ),
                  if (entries.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.monitor_weight_outlined,
                                  size: 40, color: Color(0xFFEF4444)),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No entries yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to record your first measurement.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  for (final e in entries)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.monitor_weight_rounded,
                                  color: Color(0xFFEF4444), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat.yMMMd().format(e.takenAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      for (final v
                                          in (byEntry[e.id] ?? const []))
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${typesById[v.typeId]?.name ?? '?'}: ${v.value}${typesById[v.typeId]?.unit ?? ''}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded,
                                  size: 18,
                                  color:
                                      Theme.of(context).colorScheme.error),
                              onPressed: () =>
                                  ref.read(gymDaoProvider).deleteEntry(e.id),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(32, 32),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Entry'),
        onPressed: () {
          final types = ref.read(measurementTypesStreamProvider).value ?? const [];
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
    final types =
        ref.watch(measurementTypesStreamProvider).value ?? const <MeasurementType>[];
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
                onPressed: () => ref
                    .read(gymDaoProvider)
                    .deleteMeasurementType(t.id),
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
                  decoration:
                      const InputDecoration(labelText: 'Unit', hintText: 'kg, cm'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle),
                onPressed: () async {
                  final n = controller.text.trim();
                  if (n.isEmpty) return;
                  await ref
                      .read(gymDaoProvider)
                      .upsertMeasurementType(MeasurementTypesCompanion.insert(
                        name: n,
                        unit: Value(unitController.text.trim().isEmpty
                            ? null
                            : unitController.text.trim()),
                      ));
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
    final types =
        ref.watch(measurementTypesStreamProvider).value ?? const <MeasurementType>[];
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.straighten,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.add),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
