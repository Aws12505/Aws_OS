import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/app_theme.dart';
import '../../../../shared/design/surface_scope.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_stepper.dart';
import '../exercise_identity.dart';
import '../providers.dart';

part '../widgets/workout/session_progress.dart';
part '../widgets/workout/exercise_history.dart';
part '../widgets/workout/exercise_form.dart';
part '../widgets/workout/exercise_card.dart';
part '../widgets/workout/superset_card.dart';
part '../widgets/workout/set_row.dart';

/// The workout screen.
///
/// Built around one question: can you use it one-handed, mid-set, without
/// looking closely. That is why the numbers have steppers instead of bare text
/// fields, why the tick is a 48dp target, and why the header carries a progress
/// bar rather than making you count rows.
class DayDetailScreen extends ConsumerWidget {
  const DayDetailScreen({super.key, required this.day});

  final ProgramDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(exercisesForDayProvider(day.id));
    final supersetsAsync = ref.watch(supersetsForDayProvider(day.id));

    final exercisesValue = exercisesAsync.value ?? const <DayExercise>[];
    final totalSets = exercisesValue.fold<int>(
      0,
      (sum, e) => sum + e.targetSets,
    );
    final doneSets = ref.watch(dayCheckedSetsProvider(day.id)).length;

    ref.listen<Set<String>>(dayCheckedSetsProvider(day.id), (previous, next) {
      final previousCount = previous?.length ?? 0;
      if (totalSets > 0 &&
          next.length >= totalSets &&
          previousCount < totalSets) {
        _completeDay(ref, context, day);
      }
    });

    return AppScaffold(
      mode: SurfaceMode.working,
      appBar: AppBar(
        title: Text(day.name),
        bottom: _SessionProgress(done: doneSets, total: totalSets),
      ),
      body: exercisesAsync.when(
        loading: () => const AppLoading(message: 'Loading this day'),
        error: (e, _) => AppErrorView(error: e),
        data: (exercises) {
          final supersets = supersetsAsync.value ?? const <SupersetGroup>[];
          final solo = exercises
              .where((e) => e.supersetGroupId == null)
              .toList();
          final byGroup = <String, List<DayExercise>>{};
          for (final e in exercises) {
            if (e.supersetGroupId != null) {
              byGroup.putIfAbsent(e.supersetGroupId!, () => []).add(e);
            }
          }

          if (exercises.isEmpty && supersets.isEmpty) {
            return AppEmptyState(
              icon: Icons.fitness_center_rounded,
              title: 'No exercises on this day',
              message:
                  'Add the movements you do here. Reps and weight fill in as '
                  'you train.',
              accent: context.sem.gym.base,
              action: FilledButton.icon(
                onPressed: () => _showAddExercise(
                  context,
                  dayId: day.id,
                  supersetGroupId: null,
                  nextPosition: 0,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add exercise'),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppInsets.listBottom,
            ),
            children: [
              for (final e in solo) _ExerciseCard(dayId: day.id, exercise: e),
              for (final g in supersets)
                _SupersetCard(
                  dayId: day.id,
                  group: g,
                  members: byGroup[g.id] ?? const [],
                ),
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
              final supersets =
                  ref.read(supersetsForDayProvider(day.id)).value ??
                  const <SupersetGroup>[];
              await ref
                  .read(gymDaoProvider)
                  .insertSupersetReturning(
                    dayId: day.id,
                    position: supersets.length,
                    targetSets: 3,
                  );
            },
            child: const Icon(Icons.link_rounded),
          ),
          const SizedBox(height: AppSpacing.sm),
          FloatingActionButton.extended(
            heroTag: 'addExercise',
            icon: const Icon(Icons.add_rounded),
            label: const Text('Exercise'),
            onPressed: () {
              final exercises =
                  ref.read(exercisesForDayProvider(day.id)).value ??
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

/// Every set in the day has just been ticked. Log it as a finished session and
/// reset the checklist so the ticks go back to gray for next time.
Future<void> _completeDay(
  WidgetRef ref,
  BuildContext context,
  ProgramDay day,
) async {
  await ref
      .read(gymDaoProvider)
      .insertSession(dayId: day.id, playedAt: DateTime.now());
  ref.read(dayCheckedSetsProvider(day.id).notifier).clear();
  HapticFeedback.mediumImpact();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${day.name} done, logged as a session.')),
    );
  }
}

String _fmtSetWeight(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
