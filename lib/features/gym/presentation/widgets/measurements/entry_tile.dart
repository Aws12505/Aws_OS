part of '../../screens/measurements_view.dart';

// One recorded set of readings.

class _EntryTile extends ConsumerWidget {
  const _EntryTile({
    required this.entry,
    required this.values,
    required this.typesById,
  });

  final MeasurementEntry entry;
  final List<MeasurementValue> values;
  final Map<String, MeasurementType> typesById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final surfaces = context.surfaces;
    final accent = context.sem.gym;

    return AppCard(
      style: CardStyle.block,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: accent.container,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.monitor_weight_rounded,
              color: accent.onContainer,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.yMMMd().format(entry.takenAt),
                  style: tt.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final v in values)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: surfaces.sunken,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          '${typesById[v.typeId]?.name ?? 'Unknown'} '
                          '${_fmtValue(v.value)}'
                          '${typesById[v.typeId]?.unit ?? ''}',
                          style: context.type.numericSmall,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete this entry',
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: surfaces.textTertiary,
            ),
            onPressed: () => _deleteWithUndo(context, ref),
          ),
        ],
      ),
    );
  }

  /// Deletes straight away and offers a way back, rather than interrupting
  /// with a dialog for something this small and this frequent.
  Future<void> _deleteWithUndo(BuildContext context, WidgetRef ref) async {
    final dao = ref.read(gymDaoProvider);
    final restore = {for (final v in values) v.typeId: v.value};
    final takenAt = entry.takenAt;
    final note = entry.note;

    await dao.deleteEntry(entry.id);
    HapticFeedback.lightImpact();
    if (!context.mounted) return;

    showUndoSnackBar(
      context,
      message: 'Deleted ${DateFormat.yMMMd().format(takenAt)}.',
      onUndo: () => dao.insertEntryReturning(
        takenAt: takenAt,
        values: restore,
        note: note,
      ),
    );
  }
}
