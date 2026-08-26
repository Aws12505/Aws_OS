import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../shared/design/app_theme.dart';
import '../../../shared/design/surface_scope.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pin = TextEditingController();
  String? _error;
  bool _checking = false;
  int _attempts = 0;
  DateTime? _lockedUntil;
  Timer? _ticker;

  static const _maxAttempts = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pin.dispose();
    super.dispose();
  }

  bool get _cooling =>
      _lockedUntil != null && _lockedUntil!.isAfter(DateTime.now());
  int get _cooldownLeft => _lockedUntil == null
      ? 0
      : _lockedUntil!.difference(DateTime.now()).inSeconds.clamp(0, 999);

  Future<void> _tryBiometric() async {
    if (_cooling) return;
    final auth = ref.read(authServiceProvider);
    if (!await auth.isBiometricEnabled) return;
    final ok = await auth.authenticateBiometric();
    if (ok && mounted) ref.read(lockProvider.notifier).unlock();
  }

  void _startCooldown() {
    _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (!_cooling) {
        t.cancel();
        setState(() {
          _error = null;
          _attempts = 0;
        });
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _submit() async {
    if (_cooling || _pin.text.isEmpty) return;
    setState(() {
      _error = null;
      _checking = true;
    });
    final ok = await ref.read(authServiceProvider).verifyPin(_pin.text);
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) {
      ref.read(lockProvider.notifier).unlock();
      return;
    }
    _attempts++;
    HapticFeedback.heavyImpact();
    _pin.clear();
    if (_attempts >= _maxAttempts) {
      _startCooldown();
      setState(() => _error = null);
    } else {
      setState(() =>
          _error = 'Wrong PIN. ${_maxAttempts - _attempts} attempts left.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cooling = _cooling;
    return AppScaffold(
      // Ambient: the lock screen is a moment, not a working surface.
      mode: SurfaceMode.ambient,
      bottomSafeArea: true,
      body: Center(
          child: SingleChildScrollView(
            child: GlassCard(
              blur: true,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          cs.primary,
                          Color.lerp(cs.primary, cs.tertiary, 0.6)!,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(cooling ? Icons.lock_clock_rounded : Icons.lock_rounded,
                        size: 36, color: context.sem.onPrimary),
                  ),
                  const SizedBox(height: 18),
                  Text('Aws OS',
                      style: tt.headlineSmall
                          ),
                  const SizedBox(height: 4),
                  Text(
                    cooling
                        ? 'Too many attempts. Wait ${_cooldownLeft}s'
                        : 'Enter PIN to unlock',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pin,
                    autofocus: true,
                    enabled: !cooling,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: context.type.numericLarge
                        .copyWith(fontSize: 24, letterSpacing: 12)
                        .weight(FontWeight.w700),
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(hintText: '••••'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: tt.bodySmall?.copyWith(color: cs.error),
                        textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_checking || cooling) ? null : _submit,
                      style:
                          FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                      child: Text(_checking ? 'Checking…' : 'Unlock'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: cooling ? null : _tryBiometric,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('Use biometric'),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }
}
