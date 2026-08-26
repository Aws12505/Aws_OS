part of '../../screens/day_detail_screen.dart';

void _showAddExercise(
  BuildContext context, {
  required String dayId,
  required String? supersetGroupId,
  required int nextPosition,
  DayExercise? existing,
}) {
  showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _ExerciseForm(
      dayId: dayId,
      supersetGroupId: supersetGroupId,
      nextPosition: nextPosition,
      existing: existing,
    ),
  );
}

class _ExerciseForm extends ConsumerStatefulWidget {
  const _ExerciseForm({
    required this.dayId,
    required this.supersetGroupId,
    required this.nextPosition,
    this.existing,
  });

  final String dayId;
  final String? supersetGroupId;
  final int nextPosition;
  final DayExercise? existing;

  @override
  ConsumerState<_ExerciseForm> createState() => _ExerciseFormState();
}

class _ExerciseFormState extends ConsumerState<_ExerciseForm> {
  late final TextEditingController _name;
  late final TextEditingController _sets;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.exerciseName ?? '');
    _sets = TextEditingController(text: '${widget.existing?.targetSets ?? 3}');
  }

  @override
  void dispose() {
    _name.dispose();
    _sets.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final sets = int.tryParse(_sets.text.trim()) ?? 3;
    await ref
        .read(gymDaoProvider)
        .upsertExerciseReturning(
          DayExercisesCompanion(
            id: widget.existing == null
                ? const Value.absent()
                : Value(widget.existing!.id),
            dayId: Value(widget.dayId),
            supersetGroupId: Value(widget.supersetGroupId),
            position: Value(widget.existing?.position ?? widget.nextPosition),
            exerciseName: Value(name),
            targetSets: Value(sets.clamp(1, 20)),
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentExerciseNamesProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
        left: 20,
        right: 20,
        top: AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'Add exercise' : 'Edit exercise',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Exercise name',
              hintText: 'Bench press',
            ),
            onSubmitted: (_) => _save(),
          ),
          // There is no exercise catalog, so the names already in the app are
          // the closest thing to one. Tapping a recent name keeps the spelling
          // consistent, which is what the progression chart matches on.
          if (recent.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (_, i) => ActionChip(
                  avatar: ExerciseAvatar(name: recent[i], size: 20),
                  label: Text(recent[i]),
                  onPressed: () {
                    _name.text = recent[i];
                    _name.selection = TextSelection.collapsed(
                      offset: recent[i].length,
                    );
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: 170,
            child: AppStepper(
              controller: _sets,
              label: 'Target sets',
              min: 1,
              max: 20,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(widget.existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }
}
