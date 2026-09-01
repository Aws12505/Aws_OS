part of '../../screens/tasks_screen.dart';

// First run: there is nothing to show until a workspace exists.

class _EmptyWorkspaces extends StatelessWidget {
  const _EmptyWorkspaces();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return AppScaffold(
      bottomSafeArea: true,
      body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary,
                  ),
                  child: Icon(
                    Icons.workspaces_rounded,
                    size: 48,
                    color: context.sem.onPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                Text('Create a workspace',
                    style: tt.headlineSmall
                        ),
                const SizedBox(height: 8),
                Text(
                  'Workspaces organize your tasks into focused\nspaces: work, personal, projects.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New workspace'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                  ),
                  onPressed: () => showWorkspaceFormSheet(context),
                ),
              ],
            ),
          ),
      ),
    );
  }
}
