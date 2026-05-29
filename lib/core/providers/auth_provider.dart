import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class LockState {
  const LockState({required this.lockEnabled, required this.locked});
  final bool lockEnabled;
  final bool locked;

  LockState copyWith({bool? lockEnabled, bool? locked}) => LockState(
    lockEnabled: lockEnabled ?? this.lockEnabled,
    locked: locked ?? this.locked,
  );
}

/// Tracks whether the app is currently locked. Defaults to "checking…"
/// (lockEnabled = false, locked = true) until [refresh] runs once on boot.
class LockNotifier extends StateNotifier<LockState> {
  LockNotifier(this._auth)
    : super(const LockState(lockEnabled: false, locked: true)) {
    unawaited(refresh());
  }
  final AuthService _auth;

  Future<void> refresh() async {
    final enabled = await _auth.isLockEnabled;
    // Preserve current unlocked state; only remain locked if already locked.
    final locked = enabled && state.locked;
    state = LockState(lockEnabled: enabled, locked: locked);
  }

  void unlock() => state = state.copyWith(locked: false);

  void relock() {
    if (state.lockEnabled) {
      state = state.copyWith(locked: true);
    }
  }
}

final lockProvider = StateNotifierProvider<LockNotifier, LockState>((ref) {
  return LockNotifier(ref.watch(authServiceProvider));
});
