part of '../../screens/measurements_view.dart';

// Recording a new set of readings.

void showMeasurementEntrySheet(BuildContext context) {
  showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _EntrySheet(),
    ),
  );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in at least one reading.')),
      );
      return;
    }
    await ref
        .read(gymDaoProvider)
        .insertEntryReturning(takenAt: _date, values: values);
    if (mounted) Navigator.of(context).pop();
  }

  /// The most recent reading for each type, so every field says what it was
  /// last time instead of starting blank with no context.
  Map<String, ({double value, DateTime at})> _lastReadings() {
    final entries =
        ref.watch(measurementEntriesStreamProvider).value ??
        const <MeasurementEntry>[];
    final values =
        ref.watch(measurementValuesStreamProvider).value ??
        const <MeasurementValue>[];
    final entryById = {for (final e in entries) e.id: e};

    final latest = <String, ({double value, DateTime at})>{};
    for (final v in values) {
      final at = entryById[v.entryId]?.takenAt;
      if (at == null) continue;
      final existing = latest[v.typeId];
      if (existing == null || at.isAfter(existing.at)) {
        latest[v.typeId] = (value: v.value, at: at);
      }
    }
    return latest;
  }

  @override
  Widget build(BuildContext context) {
    final types =
        ref.watch(measurementTypesStreamProvider).value ??
        const <MeasurementType>[];
    final last = _lastReadings();
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, AppSpacing.xxl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'New measurement',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(DateFormat.yMMMd().format(_date)),
              trailing: const Icon(Icons.event_rounded),
              onTap: () async {
                final d = await pickDate(context, initial: _date);
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final t in types)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: TextField(
                  controller: _controllerFor(t.id),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: context.type.numeric,
                  decoration: InputDecoration(
                    labelText: t.name,
                    suffixText: t.unit ?? '',
                    helperText: switch (last[t.id]) {
                      null => null,
                      final l =>
                        'last ${_fmtValue(l.value)}${t.unit ?? ''} '
                            'on ${DateFormat.MMMd().format(l.at)}',
                    },
                    helperStyle: context.type.numericSmall.copyWith(
                      color: surfaces.textTertiary,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => _save(types),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
