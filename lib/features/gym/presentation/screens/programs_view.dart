import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../../../shared/widgets/date_time_picker.dart';
import '../../../../shared/widgets/hero_title.dart';
import '../../../../shared/widgets/stagger.dart';
import '../providers.dart';
import 'program_detail_screen.dart';

enum _ProgramStatus { all, active, completed }

class ProgramsView extends ConsumerStatefulWidget {
  const ProgramsView({super.key});

  @override
  ConsumerState<ProgramsView> createState() => _ProgramsViewState();
}

class _ProgramsViewState extends ConsumerState<ProgramsView> {
  _ProgramStatus _status = _ProgramStatus.all;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(programsStreamProvider);
    final accent = context.sem.gym;

    return async.when(
      loading: () => const AppLoading(message: 'Loading your programs'),
      error: (e, _) => AppErrorView(error: e),
      data: (allPrograms) {
        final programs = switch (_status) {
          _ProgramStatus.all => allPrograms,
          _ProgramStatus.active =>
            allPrograms.where((p) => p.endedAt == null).toList(),
          _ProgramStatus.completed =>
            allPrograms.where((p) => p.endedAt != null).toList(),
        };

        return Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                children: [
                  for (final s in _ProgramStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: AppChip(
                        label: switch (s) {
                          _ProgramStatus.all => 'All',
                          _ProgramStatus.active => 'Active',
                          _ProgramStatus.completed => 'Finished',
                        },
                        color: accent.base,
                        selected: _status == s,
                        onTap: () => setState(() => _status = s),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: programs.isEmpty
                  ? AppEmptyState(
                      icon: Icons.list_alt_rounded,
                      title: switch (_status) {
                        _ProgramStatus.all => 'No programs yet',
                        _ProgramStatus.active => 'Nothing running',
                        _ProgramStatus.completed => 'Nothing finished yet',
                      },
                      message: switch (_status) {
                        _ProgramStatus.all =>
                          'A program is a training block, such as PPL or '
                              'Upper/Lower. Add one to start planning days.',
                        _ProgramStatus.active =>
                          'Every program here has an end date. Start a new one '
                              'to get going again.',
                        _ProgramStatus.completed =>
                          'Programs show up here once you give them an end '
                              'date.',
                      },
                      accent: accent.base,
                      action: FilledButton.icon(
                        onPressed: () => showProgramFormSheet(context),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('New program'),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppInsets.listBottom,
                      ),
                      itemCount: programs.length,
                      itemBuilder: (_, i) => StaggeredEntry(
                        index: i,
                        child: _ProgramTile(program: programs[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

void showProgramFormSheet(BuildContext context, {Program? existing}) {
  showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _ProgramForm(existing: existing),
    ),
  );
}

class _ProgramForm extends ConsumerStatefulWidget {
  const _ProgramForm({this.existing});

  final Program? existing;

  @override
  ConsumerState<_ProgramForm> createState() => _ProgramFormState();
}

class _ProgramFormState extends ConsumerState<_ProgramForm> {
  late final TextEditingController _name;
  DateTime? _startedAt;
  DateTime? _endedAt;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _startedAt = widget.existing?.startedAt ?? DateTime.now();
    _endedAt = widget.existing?.endedAt;
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
        .upsertProgramReturning(
          ProgramsCompanion(
            id: widget.existing == null
                ? const Value.absent()
                : Value(widget.existing!.id),
            name: Value(name),
            startedAt: Value(_startedAt),
            endedAt: Value(_endedAt),
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'New program' : 'Edit program',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Upper/Lower',
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Started on'),
            subtitle: Text(
              _startedAt == null
                  ? 'Not set'
                  : DateFormat.yMMMd().format(_startedAt!),
            ),
            trailing: const Icon(Icons.event_rounded),
            onTap: () async {
              final d = await pickDate(context, initial: _startedAt);
              if (d != null) setState(() => _startedAt = d);
            },
          ),
          // Modelled since the first version but never editable, which is why
          // the Finished filter could never match anything.
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Finished on'),
            subtitle: Text(
              _endedAt == null
                  ? 'Still running'
                  : DateFormat.yMMMd().format(_endedAt!),
              style: _endedAt == null
                  ? TextStyle(color: surfaces.textTertiary)
                  : null,
            ),
            trailing: _endedAt == null
                ? const Icon(Icons.event_available_rounded)
                : IconButton(
                    tooltip: 'Clear the end date',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _endedAt = null),
                  ),
            onTap: () async {
              final d = await pickDate(context, initial: _endedAt);
              if (d != null) setState(() => _endedAt = d);
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(widget.existing == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }
}

class _ProgramTile extends ConsumerWidget {
  const _ProgramTile({required this.program});

  final Program program;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final surfaces = context.surfaces;
    final accent = context.sem.gym;
    final days = ref.watch(daysForProgramProvider(program.id)).value;
    final finished = program.endedAt != null;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProgramDetailScreen(program: program),
        ),
      ),
      semanticsLabel: 'Open ${program.name}',
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: finished ? surfaces.sunken : accent.container,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              finished ? Icons.check_rounded : Icons.fitness_center_rounded,
              size: 20,
              color: finished ? surfaces.textTertiary : accent.onContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                HeroTitle(
                  tag: 'program-${program.id}',
                  text: program.name,
                  style: tt.titleMedium!,
                ),
                const SizedBox(height: 3),
                Text(
                  _programStatus(program, days?.length),
                  style: tt.bodySmall?.copyWith(color: surfaces.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More actions for ${program.name}',
            onSelected: (v) async {
              switch (v) {
                case 'edit':
                  showProgramFormSheet(context, existing: program);
                case 'finish':
                  await ref
                      .read(gymDaoProvider)
                      .upsertProgramReturning(
                        ProgramsCompanion(
                          id: Value(program.id),
                          name: Value(program.name),
                          startedAt: Value(program.startedAt),
                          endedAt: Value(finished ? null : DateTime.now()),
                        ),
                      );
                case 'delete':
                  final ok = await showAppConfirmDialog(
                    context,
                    title: 'Delete ${program.name}?',
                    message:
                        'Its days, exercises and session history are deleted '
                        'with it.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  );
                  if (ok) {
                    await ref.read(gymDaoProvider).deleteProgram(program.id);
                  }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                value: 'finish',
                child: Text(finished ? 'Reopen' : 'Mark finished'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Where this program stands: how many days it has, and when it ran.
String _programStatus(Program program, int? dayCount) {
  final shape = switch (dayCount) {
    null => null,
    0 => 'No days yet',
    1 => '1 day',
    final n => '$n days',
  };

  final when = switch ((program.startedAt, program.endedAt)) {
    (null, null) => null,
    (final start?, null) => 'since ${DateFormat.yMMMd().format(start)}',
    (null, final end?) => 'finished ${DateFormat.yMMMd().format(end)}',
    (final start?, final end?) =>
      '${DateFormat.yMMMd().format(start)} to ${DateFormat.yMMMd().format(end)}',
  };

  if (shape == null) return when ?? 'No dates set';
  if (when == null) return shape;
  return '$shape, $when';
}
