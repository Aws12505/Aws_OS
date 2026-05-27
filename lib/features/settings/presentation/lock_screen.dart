import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pin = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final auth = ref.read(authServiceProvider);
    if (!await auth.isBiometricEnabled) return;
    final ok = await auth.authenticateBiometric();
    if (ok && mounted) {
      ref.read(lockProvider.notifier).unlock();
    }
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _checking = true;
    });
    final ok = await ref.read(authServiceProvider).verifyPin(_pin.text);
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) {
      ref.read(lockProvider.notifier).unlock();
    } else {
      setState(() {
        _error = 'Wrong PIN.';
        _pin.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline,
                  size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text('Aws OS', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Enter PIN to unlock'),
              const SizedBox(height: 24),
              TextField(
                controller: _pin,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(letterSpacing: 8, fontSize: 24),
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                    border: OutlineInputBorder()),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _checking ? null : _submit,
                child: Text(_checking ? 'Checking…' : 'Unlock'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _tryBiometric,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Use biometric'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
