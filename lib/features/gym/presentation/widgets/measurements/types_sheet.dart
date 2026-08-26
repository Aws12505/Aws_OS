part of '../../screens/measurements_view.dart';

// Deciding what to track.

void showMeasurementTypesSheet(BuildContext context) {
  showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _TypesSheet(),
    ),
  );
}

/// Stateful so the two text controllers have an owner that disposes them. The
/// previous version created them inside `build` of a `ConsumerWidget`, so every
/// rebuild leaked a pair and reset whatever had been typed.
class _TypesSheet extends ConsumerStatefulWidget {
  const _TypesSheet();

  @override
  ConsumerState<_TypesSheet> createState() => _TypesSheetState();
}

class _TypesSheetState extends ConsumerState<_TypesSheet> {
  final _name = TextEditingController();
  final _unit = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final unit = _unit.text.trim();
    await ref
        .read(gymDaoProvider)
        .upsertMeasurementType(
          MeasurementTypesCompanion.insert(
            name: name,
            unit: Value(unit.isEmpty ? null : unit),
          ),
        );
    _name.clear();
    _unit.clear();
  }

  @override
  Widget build(BuildContext context) {
    final types =
        ref.watch(measurementTypesStreamProvider).value ??
        const <MeasurementType>[];
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Measurement types',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          if (types.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                'Nothing tracked yet. Add one below, such as Weight in kg.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: surfaces.textSecondary,
                ),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in types)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: t.unit == null
                            ? null
                            : Text(
                                t.unit!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        trailing: IconButton(
                          tooltip: 'Delete ${t.name}',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () async {
                            // Readings reference the type, so removing one
                            // that is in use is not recoverable by re-adding
                            // it. Worth a confirmation.
                            final ok = await showAppConfirmDialog(
                              context,
                              title: 'Delete ${t.name}?',
                              message:
                                  'Readings already recorded against it stop '
                                  'showing up.',
                              confirmLabel: 'Delete',
                              destructive: true,
                            );
                            if (ok) {
                              await ref
                                  .read(gymDaoProvider)
                                  .deleteMeasurementType(t.id);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Waist',
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 92,
                child: TextField(
                  controller: _unit,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    hintText: 'cm',
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filledTonal(
                tooltip: 'Add this type',
                icon: const Icon(Icons.add_rounded),
                onPressed: _add,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
