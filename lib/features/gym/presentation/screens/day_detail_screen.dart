import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../providers.dart';

class DayDetailScreen extends ConsumerWidget {
  const DayDetailScreen({super.key, required this.day});
  final ProgramDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(exercisesForDayProvider(day.id));
    final supersetsAsync = ref.watch(supersetsForDayProvider(day.id));

    final exercisesValue = exercisesAsync.value ?? const <DayExercise>[];
    final totalSets = exercisesValue.fold<int>(0, (sum, e) => sum + e.targetSets);

    ref.listen<Set<String>>(dayCheckedSetsProvider(day.id), (previous, next) {
      final previousCount = previous?.length ?? 0;
      if (totalSets > 0 && next.length >= totalSets && previousCount < totalSets) {
        _completeDay(ref, context, day);
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(day.name)),
      body: exercisesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (exercises) {
          final supersets = supersetsAsync.value ?? const <SupersetGroup>[];
          final solo = exercises.where((e) => e.supersetGroupId == null).toList();
          final byGroup = <String, List<DayExercise>>{};
          for (final e in exercises) {
            if (e.supersetGroupId != null) {
              byGroup.putIfAbsent(e.supersetGroupId!, () => []).add(e);
            }
          }
          if (exercises.isEmpty && supersets.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No exercises yet. Tap + to add one or a superset.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
            children: [
              for (final e in solo) _ExerciseTile(dayId: day.id, exercise: e),
              for (final g in supersets) ...[
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.link),
                            const SizedBox(width: 8),
                            Text(
                              'Superset — ${g.targetSets} round(s)',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => ref
                                  .read(gymDaoProvider)
                                  .deleteSuperset(g.id),
                            ),
                          ],
                        ),
                        for (final e in (byGroup[g.id] ?? const []))
                          _ExerciseTile(dayId: day.id, exercise: e, inside: true),
                        TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add to superset'),
                          onPressed: () => _showAddExercise(
                            context,
                            dayId: day.id,
                            supersetGroupId: g.id,
                            nextPosition: (byGroup[g.id]?.length ?? 0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'addSuperset',
            tooltip: 'Add superset',
            onPressed: () async {
              final supersets = ref.read(supersetsForDayProvider(day.id)).value ??
                  const <SupersetGroup>[];
              await ref.read(gymDaoProvider).insertSupersetReturning(
                    dayId: day.id,
                    position: supersets.length,
                    targetSets: 3,
                  );
            },
            child: const Icon(Icons.link),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'addExercise',
            icon: const Icon(Icons.add),
            label: const Text('Exercise'),
            onPressed: () {
              final exercises = ref.read(exercisesForDayProvider(day.id)).value ??
                  const <DayExercise>[];
              _showAddExercise(
                context,
                dayId: day.id,
                supersetGroupId: null,
                nextPosition: exercises.length,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Every set in the day has just been ticked. Log it as a finished session
/// and reset the checklist so the ticks go back to gray for next time.
Future<void> _completeDay(
  WidgetRef ref,
  BuildContext context,
  ProgramDay day,
) async {
  await ref.read(gymDaoProvider).insertSession(
        dayId: day.id,
        playedAt: DateTime.now(),
      );
  ref.read(dayCheckedSetsProvider(day.id).notifier).clear();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${day.name} complete — logged as a session!'),
    ));
  }
}

String _fmtSetWeight(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Full, all-time prescription history for one exercise (every set index,
/// every edit), opened as a sheet over the day screen so the user never
/// has to leave it to see their progression.
void _showExerciseHistory(BuildContext context, {required DayExercise exercise}) {
  showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => Consumer(builder: (ctx2, ref, _) {
      final prescriptionsAsync =
          ref.watch(prescriptionsForExerciseProvider(exercise.id));
      final byIndex = <int, List<ExerciseSetPrescription>>{};
      for (final p
          in (prescriptionsAsync.value ?? const <ExerciseSetPrescription>[])) {
        byIndex.putIfAbsent(p.setIndex, () => []).add(p);
      }
      final indices = byIndex.keys.toList()..sort();
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx3, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text('${exercise.exerciseName} — history',
                style: Theme.of(ctx3).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (indices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No history yet — check off a set to start logging.'),
              )
            else
              for (final i in indices) ...[
                Text('Set #$i', style: Theme.of(ctx3).textTheme.titleSmall),
                for (final p in byIndex[i]!)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${p.reps} × ${_fmtSetWeight(p.weight)}'),
                        ),
                        Text(
                          DateFormat.yMMMd().add_jm().format(p.effectiveFrom),
                          style: Theme.of(ctx3).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                const Divider(),
              ],
          ],
        ),
      );
    }),
  );
}

void _showAddExercise(
  BuildContext context, {
  required String dayId,
  required String? supersetGroupId,
  required int nextPosition,
  DayExercise? existing,
}) {
  final name = TextEditingController(text: existing?.exerciseName ?? '');
  int sets = existing?.targetSets ?? 3;
  showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 8,
      ),
      child: Consumer(builder: (ctx2, ref, _) {
        return StatefulBuilder(builder: (ctx3, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? 'Add exercise' : 'Edit exercise',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Exercise name',
                    hintText: 'Bench press, Row, …'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Target sets'),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Slider(
                      min: 1,
                      max: 10,
                      divisions: 9,
                      value: sets.toDouble(),
                      label: '$sets',
                      onChanged: (v) => setState(() => sets = v.round()),
                    ),
                  ),
                  Text('$sets'),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final n = name.text.trim();
                  if (n.isEmpty) return;
                  await ref.read(gymDaoProvider).upsertExerciseReturning(
                        DayExercisesCompanion(
                          id: existing == null
                              ? const Value.absent()
                              : Value(existing.id),
                          dayId: Value(dayId),
                          supersetGroupId: Value(supersetGroupId),
                          position: Value(existing?.position ?? nextPosition),
                          exerciseName: Value(n),
                          targetSets: Value(sets),
                        ),
                      );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
              const SizedBox(height: 24),
            ],
          );
        });
      }),
    ),
  );
}

class _ExerciseTile extends ConsumerWidget {
  const _ExerciseTile({
    required this.dayId,
    required this.exercise,
    this.inside = false,
  });
  final String dayId;
  final DayExercise exercise;
  final bool inside;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptionsAsync =
        ref.watch(prescriptionsForExerciseProvider(exercise.id));
    // Group prescriptions by set_index; the query already orders each
    // group newest-first (via effectiveFrom desc), so index 0 is current
    // and index 1 (if present) is the previous entry.
    final byIndex = <int, List<ExerciseSetPrescription>>{};
    for (final p in (prescriptionsAsync.value ?? const <ExerciseSetPrescription>[])) {
      byIndex.putIfAbsent(p.setIndex, () => []).add(p);
    }
    final tile = Card(
      margin: inside ? const EdgeInsets.symmetric(vertical: 2) : null,
      color: inside ? Theme.of(context).colorScheme.surface : null,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fitness_center),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(exercise.exerciseName,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Text('${exercise.targetSets} sets',
                    style: Theme.of(context).textTheme.bodySmall),
                IconButton(
                  tooltip: 'Full history',
                  icon: const Icon(Icons.history),
                  onPressed: () =>
                      _showExerciseHistory(context, exercise: exercise),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'edit':
                        _showAddExercise(
                          context,
                          dayId: exercise.dayId,
                          supersetGroupId: exercise.supersetGroupId,
                          nextPosition: exercise.position,
                          existing: exercise,
                        );
                      case 'delete':
                        await ref
                            .read(gymDaoProvider)
                            .deleteExercise(exercise.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            for (var i = 1; i <= exercise.targetSets; i++)
              _SetRow(
                dayId: dayId,
                exerciseId: exercise.id,
                setIndex: i,
                current: (byIndex[i]?.isNotEmpty ?? false) ? byIndex[i]![0] : null,
                previous: (byIndex[i]?.length ?? 0) > 1 ? byIndex[i]![1] : null,
              ),
          ],
        ),
      ),
    );
    return tile;
  }
}

class _SetRow extends ConsumerStatefulWidget {
  const _SetRow({
    required this.dayId,
    required this.exerciseId,
    required this.setIndex,
    required this.current,
    required this.previous,
  });
  final String dayId;
  final String exerciseId;
  final int setIndex;
  final ExerciseSetPrescription? current;
  final ExerciseSetPrescription? previous;
  @override
  ConsumerState<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<_SetRow> {
  late final TextEditingController _reps;
  late final TextEditingController _weight;

  @override
  void initState() {
    super.initState();
    _reps = TextEditingController(
        text: widget.current?.reps.toString() ?? '');
    _weight = TextEditingController(
        text: widget.current?.weight.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current?.id != widget.current?.id) {
      _reps.text = widget.current?.reps.toString() ?? '';
      _weight.text = widget.current?.weight.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    super.dispose();
  }

  String get _checkKey => '${widget.exerciseId}#${widget.setIndex}';

  /// Parses the fields and, if they're valid, persists them as a new
  /// prescription row (unless unchanged from the current one). Returns
  /// false — with a snackbar explaining why — if the fields aren't usable,
  /// so a tick press is never a silent no-op.
  Future<bool> _trySave() async {
    final reps = int.tryParse(_reps.text.trim());
    final weight = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    if (reps == null || weight == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter reps and weight before checking off this set.'),
        ));
      }
      return false;
    }
    final unchanged = widget.current != null &&
        widget.current!.reps == reps &&
        (widget.current!.weight - weight).abs() < 1e-9;
    if (!unchanged) {
      await ref.read(gymDaoProvider).insertPrescription(
            dayExerciseId: widget.exerciseId,
            setIndex: widget.setIndex,
            reps: reps,
            weight: weight,
          );
    }
    return true;
  }

  Future<void> _onCheckPressed() async {
    final notifier = ref.read(dayCheckedSetsProvider(widget.dayId).notifier);
    final isChecked =
        ref.read(dayCheckedSetsProvider(widget.dayId)).contains(_checkKey);
    if (isChecked) {
      notifier.uncheck(_checkKey);
      return;
    }
    if (await _trySave()) {
      notifier.check(_checkKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChecked = ref
        .watch(dayCheckedSetsProvider(widget.dayId))
        .contains(_checkKey);
    final previous = widget.previous;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 32, child: Text('#${widget.setIndex}')),
              Expanded(
                child: TextField(
                  controller: _reps,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                      labelText: 'Reps', isDense: true),
                  onSubmitted: (_) => _trySave(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Weight', isDense: true),
                  onSubmitted: (_) => _trySave(),
                ),
              ),
              IconButton(
                tooltip: isChecked ? 'Uncheck set' : 'Check off set',
                icon: Icon(
                  isChecked ? Icons.check_circle : Icons.check_circle_outline,
                  color: isChecked ? Colors.green : Colors.grey,
                ),
                onPressed: _onCheckPressed,
              ),
            ],
          ),
          if (previous != null)
            Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 2),
              child: Text(
                'Previous: ${previous.reps} × ${_fmtSetWeight(previous.weight)}'
                ' (${DateFormat.MMMd().format(previous.effectiveFrom)})',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            ),
        ],
      ),
    );
  }
}
