import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/app_theme.dart';
import '../../../../shared/design/color_ops.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_filter_bar.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../providers.dart';
import '../task_filter.dart';
import '../widgets/task_filter_sheet.dart';
import '../widgets/task_form_sheet.dart';
import '../widgets/workspace_form_sheet.dart';
import 'task_detail_screen.dart';
import 'task_history_screen.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/stagger.dart';

part '../widgets/home/empty_workspaces.dart';
part '../widgets/home/workspace_card.dart';
part '../widgets/home/workspace_task_list.dart';
part '../widgets/home/task_tile.dart';

/// A workspace's colour: its own if it has one, otherwise the shared chart
/// palette, which is already nudged toward the user's seed and corrected for
/// contrast. The private eight-colour list this replaced was a copy of that
/// palette with none of the correction.
Color _wsColor(BuildContext context, Workspace w, int i) =>
    w.color != null ? Color(w.color!) : context.sem.chartAt(i);

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workspacesStreamProvider);
    return async.when(
      loading: () =>
          const AppScaffold(
            body: AppLoading(message: 'Loading your workspaces'),
          ),
      error: (e, _) => AppScaffold(
        body: AppErrorView(error: e),
      ),
      data: (workspaces) {
        if (workspaces.isEmpty) return const _EmptyWorkspaces();
        return _TasksHome(workspaces: workspaces);
      },
    );
  }
}

// ── empty ────────────────────────────────────────────────────────────────────

// ── home ─────────────────────────────────────────────────────────────────────

class _TasksHome extends ConsumerStatefulWidget {
  const _TasksHome({required this.workspaces});
  final List<Workspace> workspaces;
  @override
  ConsumerState<_TasksHome> createState() => _TasksHomeState();
}

class _TasksHomeState extends ConsumerState<_TasksHome> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void didUpdateWidget(covariant _TasksHome old) {
    super.didUpdateWidget(old);
    if (_index >= widget.workspaces.length) {
      _index = widget.workspaces.length - 1;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _select(int i) {
    setState(() => _index = i);
    _pageController.animateToPage(
      i,
      duration: context.motion.long,
      curve: context.motion.emphasized,
          );
  }

  @override
  Widget build(BuildContext context) {
    final workspaces = widget.workspaces;
    final allTasks =
        ref.watch(allTasksStreamProvider).value ?? const <Task>[];
    final counts = <String, ({int done, int total})>{};
    for (final w in workspaces) {
      final ws = allTasks.where((t) => t.workspaceId == w.id);
      counts[w.id] = (
        done: ws.where((t) => t.isCompleted).length,
        total: ws.length,
      );
    }
    final active = workspaces[_index.clamp(0, workspaces.length - 1)];
    final accent = _wsColor(context, active, _index);

    return AppScaffold(
      // Working mode: this is a list screen, and a translucent card behind a
      // dense task list costs more legibility than it buys atmosphere. The
      // workspace accent lives in the cards and the rail, not in a second
      // background gradient stacked on the global one.
      body: Column(
            children: [
              SectionHeader(
                title: 'Tasks',
                status: _openStatus(counts, workspaces),
                statusIcon: Icons.checklist_rounded,
                statusColor: accent,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Carry unfinished tasks to tomorrow',
                      icon: const Icon(Icons.event_repeat_rounded),
                      onPressed: () async {
                        final moved = await ref
                            .read(tasksRepositoryProvider)
                            .carryOverUnfinished(from: DateTime.now());
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(moved == 0
                                ? 'Nothing to carry over'
                                : 'Moved $moved task${moved == 1 ? '' : 's'} to tomorrow'),
                          ));
                        }
                      },
                    ),
                    IconButton.filledTonal(
                      tooltip: 'New workspace',
                      icon: const Icon(Icons.create_new_folder_rounded),
                      onPressed: () => showWorkspaceFormSheet(context),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 156,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: workspaces.length,
                  itemBuilder: (_, i) {
                    final w = workspaces[i];
                    final c = counts[w.id] ?? (done: 0, total: 0);
                    return _WorkspaceCard(
                      name: w.name,
                      color: _wsColor(context, w, i),
                      done: c.done,
                      total: c.total,
                      selected: i == _index,
                      onTap: () => _select(i),
                    );
                  },
                ),
              ),
              const _FilterBar(),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemCount: workspaces.length,
                  itemBuilder: (_, i) =>
                      _WorkspaceTaskList(workspace: workspaces[i]),
                ),
              ),
            ],
          ),
    );
  }
}

// ── workspace card ─────────────────────────────────────────────────────────

// ── per-workspace list ───────────────────────────────────────────────────────

// ── filter bar ───────────────────────────────────────────────────────────────

// ── per-workspace list ───────────────────────────────────────────────────────

/// One line saying how much is left across every workspace.
String _openStatus(
  Map<String, ({int done, int total})> counts,
  List<Workspace> workspaces,
) {
  var done = 0;
  var total = 0;
  for (final w in workspaces) {
    final c = counts[w.id];
    if (c == null) continue;
    done += c.done;
    total += c.total;
  }
  if (total == 0) return 'Nothing scheduled';
  final open = total - done;
  if (open == 0) return 'All $total done';
  return '$open of $total still open';
}
