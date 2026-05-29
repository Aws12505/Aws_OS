import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/auth_provider.dart' as auth;
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/finance/presentation/screens/finance_screen.dart';
import '../features/gym/presentation/screens/gym_screen.dart';
import '../features/notes/presentation/screens/notes_screen.dart';
import '../features/settings/presentation/lock_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/tasks/presentation/screens/tasks_screen.dart';
import '../shared/widgets/main_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _RouterRefresh(ref),
    redirect: (context, state) {
      final lock = ref.read(auth.lockProvider);
      final isLockScreen = state.uri.path == '/lock';
      if (lock.lockEnabled && lock.locked && !isLockScreen) return '/lock';
      if (!lock.locked && isLockScreen) return '/';
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return MainScaffold(location: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: '/finance',
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: FinanceScreen()),
          ),
          GoRoute(
            path: '/tasks',
            pageBuilder: (c, s) => const NoTransitionPage(child: TasksScreen()),
          ),
          GoRoute(
            path: '/gym',
            pageBuilder: (c, s) => const NoTransitionPage(child: GymScreen()),
          ),
          GoRoute(
            path: '/notes',
            pageBuilder: (c, s) => const NoTransitionPage(child: NotesScreen()),
          ),
        ],
      ),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/lock', builder: (c, s) => const LockScreen()),
    ],
  );
});

/// Bridges Riverpod's `lockProvider` to go_router's redirect — go_router
/// re-runs `redirect` when this Listenable notifies.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this.ref) {
    ref.listen<auth.LockState>(auth.lockProvider, (_, _) => notifyListeners());
  }
  final Ref ref;
}
