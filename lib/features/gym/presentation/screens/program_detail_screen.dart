import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../providers.dart';
import 'day_detail_screen.dart';

class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({super.key, required this.program});
  final Program program;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(daysForProgramProvider(program.id));
    return Scaffold(
      appBar: AppBar(title: Text(program.name)),
      body: daysAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (days) {
          if (days.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No days yet. Tap + to add one (e.g. Push, Pull, Legs).',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
            itemCount: days.length,
            itemBuilder: (_, i) => _DayTile(day: days[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Day'),
        onPressed: () async {
          final existing = ref.read(daysForProgramProvider(program.id)).value ??
              const <ProgramDay>[];
          _showDayForm(context, programId: program.id,
              nextPosition: existing.length);
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
  final controller = TextEditingController(text: existing?.name ?? '');
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'New day' : 'Edit day',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Name', hintText: 'Push, Pull, Chest, …'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                await ref.read(gymDaoProvider).upsertDayReturning(
                      ProgramDaysCompanion(
                        id: existing == null
                            ? const Value.absent()
                            : Value(existing.id),
                        programId: Value(programId),
                        name: Value(name),
                        position: Value(existing?.position ?? nextPosition),
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
      }),
    ),
  );
}

class _DayTile extends ConsumerWidget {
  const _DayTile({required this.day});
  final ProgramDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsForDayProvider(day.id)).value ??
        const <DaySession>[];
    final lastPlayed = sessions.isEmpty ? null : sessions.first.playedAt;
    return Card(
      child: ListTile(
        title: Text(day.name),
        subtitle: Text(lastPlayed == null
            ? 'Never played'
            : 'Last played ${DateFormat.yMMMd().format(lastPlayed)}'
                ' • ${sessions.length} session(s)'),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Log session',
              icon: const Icon(Icons.play_circle_outline),
              onPressed: () async {
                await ref.read(gymDaoProvider).insertSession(
                      dayId: day.id,
                      playedAt: DateTime.now(),
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Logged ${day.name}.'),
                  ));
                }
              },
            ),
            PopupMenuButton<String>(
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
                    await ref.read(gymDaoProvider).deleteDay(day.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DayDetailScreen(day: day),
        )),
      ),
    );
  }
}
