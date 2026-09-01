import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/auth_provider.dart' as auth;
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/dashboard/presentation/debrief_screen.dart';
import '../features/mentor/data/forecast_service.dart';
import '../features/mentor/presentation/mentor_screen.dart';
import '../features/finance/presentation/screens/finance_screen.dart';
import '../features/gym/presentation/screens/gym_screen.dart';
import '../features/notes/presentation/screens/notes_screen.dart';
import '../features/settings/presentation/lock_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/sharing/presentation/sharing_screen.dart';
import '../features/tasks/presentation/screens/tasks_screen.dart';
import '../shared/design/app_theme.dart';
import '../shared/widgets/main_scaffold.dart';
import 'shell_navigator.dart';

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
        navigatorKey: shellNavigatorKey,
        observers: [ShellDepthObserver()],
        builder: (context, state, child) {
          return MainScaffold(location: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (c, s) =>
                _fadeThrough(c, const DashboardScreen()),
          ),
          GoRoute(
            path: '/finance',
            pageBuilder: (c, s) =>
                _fadeThrough(c, const FinanceScreen()),
          ),
          GoRoute(
            path: '/tasks',
            pageBuilder: (c, s) => _fadeThrough(c, const TasksScreen()),
          ),
          GoRoute(
            path: '/gym',
            pageBuilder: (c, s) => _fadeThrough(c, const GymScreen()),
          ),
          GoRoute(
            path: '/notes',
            pageBuilder: (c, s) => _fadeThrough(c, const NotesScreen()),
          ),
          GoRoute(
            path: '/sharing',
            pageBuilder: (c, s) =>
                _fadeThrough(c, const SharingScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/debrief',
        pageBuilder: (c, s) {
          final raw = s.uri.queryParameters['date'];
          final date = raw != null ? DateTime.tryParse(raw) : null;
          return _detailPage(c, DebriefScreen(date: date));
        },
      ),
      GoRoute(
        path: '/mentor',
        pageBuilder: (c, s) {
          final raw = s.uri.queryParameters['kind'];
          final kind = MentorKind.values.firstWhere(
            (k) => k.name == raw,
            orElse: () => MentorKind.finance,
          );
          return _detailPage(c, MentorScreen(kind: kind));
        },
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (c, s) => _detailPage(c, const SettingsScreen()),
      ),
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

/// Content-only fade between the six shell tabs.
///
/// These are peers, so nothing should slide: a direction would imply a
/// hierarchy that is not there. Only the content crossfades — the nav bar and
/// the page background are above the router, so they stay still through the
/// swap and the movement reads as the content changing, not the app.
CustomTransitionPage<void> _fadeThrough(BuildContext context, Widget child) {
  final motion = context.motion;
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: motion.short,
    reverseTransitionDuration: motion.quick,
    transitionsBuilder: (_, animation, _, page) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: motion.standardCurve),
      child: page,
    ),
  );
}

/// One transition for every pushed detail route, defined here rather than
/// per route so they cannot drift apart.
CustomTransitionPage<void> _detailPage(BuildContext context, Widget child) {
  final motion = context.motion;
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: motion.medium,
    reverseTransitionDuration: motion.short,
    transitionsBuilder: (_, animation, _, page) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: motion.enter,
        reverseCurve: motion.exit,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
          child: page,
        ),
      );
    },
  );
}
