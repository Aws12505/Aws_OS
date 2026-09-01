import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/hero_title.dart';
import '../../../../shared/widgets/stagger.dart';
import '../providers.dart';
import 'day_detail_screen.dart';

class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({super.key, required this.program});

  final Program program;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(daysForProgramProvider(program.id));

    return AppScaffold(
      appBar: AppBar(
        title: HeroTitle(
          tag: 'program-${program.id}',
          text: program.name,
          style: Theme.of(context).appBarTheme.titleTextStyle ??
              Theme.of(context).textTheme.titleLarge!,
        ),
      ),
      body: daysAsync.when(
        loading: () => const AppLoading(message: 'Loading this program'),
        error: (e, _) => AppErrorView(error: e),
        data: (days) {
          if (days.isEmpty) {
            return AppEmptyState(
              icon: Icons.calendar_view_week_rounded,
              title: 'No days in this program',
              message:
                  'Split it into the days you train, such as Push, Pull and '
                  'Legs.',
              accent: context.sem.gym.base,
              action: FilledButton.icon(
                onPressed: () => _showDayForm(
                  context,
                  programId: program.id,
                  nextPosition: 0,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add a day'),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppInsets.listBottom,
            ),
            itemCount: days.length,
            itemBuilder: (_, i) =>
                StaggeredEntry(index: i, child: _DayTile(day: days[i])),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('Day'),
        onPressed: () {
          final existing =
              ref.read(daysForProgramProvider(program.id)).value ??
              const <ProgramDay>[];
          _showDayForm(
            context,
            programId: program.id,
            nextPosition: existing.length,
          );
        },
      ),
    );
  }
}

void _showDayForm(
  BuildContext context, {
  required String programId,
  required int nextPosition,
  ProgramDay? existing,
}) {
  showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _DayForm(
        programId: programId,
        nextPosition: nextPosition,
        existing: existing,
    ),
  );
}

/// A stateful form so the controller has an owner that disposes it. The old
/// version created one outside the sheet builder and leaked it on every open.
class _DayForm extends ConsumerStatefulWidget {
  const _DayForm({
    required this.programId,
    required this.nextPosition,
    this.existing,
  });

  final String programId;
  final int nextPosition;
  final ProgramDay? existing;

  @override
  ConsumerState<_DayForm> createState() => _DayFormState();
}

class _DayFormState extends ConsumerState<_DayForm> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await ref
        .read(gymDaoProvider)
        .upsertDayReturning(
          ProgramDaysCompanion(
            id: widget.existing == null
                ? const Value.absent()
                : Value(widget.existing!.id),
            programId: Value(widget.programId),
            name: Value(name),
            position: Value(widget.existing?.position ?? widget.nextPosition),
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
            widget.existing == null ? 'New day' : 'Edit day',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Push',
            ),
            onSubmitted: (_) => _save(),
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

class _DayTile extends ConsumerWidget {
  const _DayTile({required this.day});

  final ProgramDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions =
        ref.watch(sessionsForDayProvider(day.id)).value ??
        const <DaySession>[];
    final exercises =
        ref.watch(exercisesForDayProvider(day.id)).value ??
        const <DayExercise>[];
    final lastPlayed = sessions.isEmpty ? null : sessions.first.playedAt;

    final surfaces = context.surfaces;
    final accent = context.sem.gym;
    final tt = Theme.of(context).textTheme;
    final totalSets = exercises.fold<int>(0, (s, e) => s + e.targetSets);

    return AppCard(
      style: CardStyle.block,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      // Shell navigator, like every other detail push: the nav bar has to stay
      // reachable. Covering it meant a tab tap mid-workout did nothing until
      // you had pressed back out of the screen.
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DayDetailScreen(day: day)),
      ),
      semanticsLabel: 'Open ${day.name}',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  day.name,
                  style: tt.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _dayStatus(
                    lastPlayed: lastPlayed,
                    sessionCount: sessions.length,
                    exerciseCount: exercises.length,
                    totalSets: totalSets,
                  ),
                  style: tt.bodySmall?.copyWith(
                    color: surfaces.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Logs a session without opening the day: for when the workout is
          // already done and only needs recording.
          IconButton(
            tooltip: 'Log a session for ${day.name}',
            icon: Icon(Icons.play_circle_outline_rounded, color: accent.fg),
            onPressed: () async {
              await ref
                  .read(gymDaoProvider)
                  .insertSession(dayId: day.id, playedAt: DateTime.now());
              HapticFeedback.lightImpact();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Logged ${day.name}.')),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'More actions for ${day.name}',
            onSelected: (v) async {
              switch (v) {
                case 'edit':
                  _showDayForm(
                    context,
                    programId: day.programId,
                    nextPosition: day.position,
                    existing: day,
                  );
                case 'delete':
                  final ok = await showAppConfirmDialog(
                    context,
                    title: 'Delete ${day.name}?',
                    message:
                        'Its exercises, logged reps and weights, and session '
                        'history are deleted with it.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  );
                  if (ok) {
                    await ref.read(gymDaoProvider).deleteDay(day.id);
                  }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

/// One line saying where this day stands, rather than a bare "Never played".
String _dayStatus({
  required DateTime? lastPlayed,
  required int sessionCount,
  required int exerciseCount,
  required int totalSets,
}) {
  if (exerciseCount == 0) return 'No exercises yet';

  final shape = totalSets == 0
      ? '$exerciseCount exercises'
      : '$exerciseCount exercises, $totalSets sets';

  if (lastPlayed == null) return '$shape, never trained';

  final days = DateTime.now().difference(lastPlayed).inDays;
  final when = switch (days) {
    <= 0 => 'today',
    1 => 'yesterday',
    final d when d < 30 => '$d days ago',
    _ => 'on ${DateFormat.yMMMd().format(lastPlayed)}',
  };
  return '$shape, last trained $when';
}
