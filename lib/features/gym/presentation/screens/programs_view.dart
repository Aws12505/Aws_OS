import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../providers.dart';
import 'program_detail_screen.dart';

class ProgramsView extends ConsumerWidget {
  const ProgramsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(programsStreamProvider);
    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (programs) {
          if (programs.isEmpty) {
            return const _ProgramsEmpty();
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
            itemCount: programs.length,
            itemBuilder: (_, i) => _ProgramTile(program: programs[i]),
          );
        },
      ),
    );
  }
}

void showProgramFormSheet(BuildContext context, {Program? existing}) {
  showModalBottomSheet<void>(
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

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _startedAt = widget.existing?.startedAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final companion = ProgramsCompanion(
      id: widget.existing == null
          ? const Value.absent()
          : Value(widget.existing!.id),
      name: Value(name),
      startedAt: Value(_startedAt),
    );
    await ref.read(gymDaoProvider).upsertProgramReturning(companion);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing == null ? 'New program' : 'Edit program',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: 'Name', hintText: 'PPL, Upper/Lower, …'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Started on'),
            subtitle: Text(_startedAt == null
                ? '—'
                : DateFormat.yMMMd().format(_startedAt!)),
            trailing: const Icon(Icons.event),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _startedAt ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => _startedAt = d);
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFFEF4444);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, Color.lerp(accent, Colors.black, 0.25)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.fitness_center_rounded,
              color: Colors.white, size: 22),
        ),
        title: Text(program.name,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text(
            program.startedAt == null
                ? 'No start date'
                : 'Started ${DateFormat.yMMMd().format(program.startedAt!)}',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            switch (v) {
              case 'edit':
                showProgramFormSheet(context, existing: program);
              case 'delete':
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: Text('Delete ${program.name}?'),
                    content: const Text(
                        'Days, exercises, and history under it will be removed.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(gymDaoProvider).deleteProgram(program.id);
                }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => ProgramDetailScreen(program: program),
          ),
        ),
      ),
    );
  }
}

class _ProgramsEmpty extends StatelessWidget {
  const _ProgramsEmpty();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.list_alt_rounded,
                  size: 40, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 20),
            Text('No programs yet',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Tap + to add one (e.g. PPL, Upper/Lower).',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
