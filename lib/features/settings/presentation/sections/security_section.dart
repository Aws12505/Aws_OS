part of '../settings_screen.dart';

// PIN and biometric lock.

class _SecuritySection extends ConsumerStatefulWidget {
  const _SecuritySection();
  @override
  ConsumerState<_SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends ConsumerState<_SecuritySection> {
  bool? _pinSet;
  bool? _bioEnabled;
  AuthService get _auth => ref.read(authServiceProvider);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final pinSet = await _auth.isPinSet;
    final bio = await _auth.isBiometricEnabled;
    if (!mounted) return;
    setState(() {
      _pinSet = pinSet;
      _bioEnabled = bio;
    });
    ref.read(lockProvider.notifier).refresh();
  }

  Future<void> _setPin() async {
    final pin = await _askPin('Set PIN');
    if (pin == null) return;
    await _auth.setPin(pin);
    await _refresh();
  }

  Future<void> _changePin() async {
    final current = await _askPin('Current PIN');
    if (current == null) return;
    if (!await _auth.verifyPin(current)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Wrong PIN.')));
      }
      return;
    }
    final next = await _askPin('New PIN');
    if (next == null) return;
    await _auth.setPin(next);
    await _refresh();
  }

  Future<void> _clearPin() async {
    final current = await _askPin('Confirm current PIN');
    if (current == null) return;
    if (!await _auth.verifyPin(current)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Wrong PIN.')));
      }
      return;
    }
    await _auth.clearPin();
    await _refresh();
  }

  Future<String?> _askPin(String title) async {
    final controller = TextEditingController();
    return showAppDialog<String>(
    context,
    builder: (dCtx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'PIN (4 to 8 digits)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.length < 4 || v.length > 8) return;
              Navigator.pop(dCtx, v);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinSet = _pinSet;
    final bio = _bioEnabled;
    if (pinSet == null || bio == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: AppLoading(),
      );
    }
    return Column(
      children: [
        SwitchListTile(
          title: const Text('PIN unlock'),
          subtitle: Text(
            pinSet ? 'Enabled. Tap below to change or clear' : 'Disabled',
          ),
          value: pinSet,
          onChanged: (v) async {
            if (v) {
              await _setPin();
            } else {
              await _clearPin();
            }
          },
        ),
        if (pinSet)
          ListTile(
            title: const Text('Change PIN'),
            trailing: const Icon(Icons.edit),
            onTap: _changePin,
          ),
        SwitchListTile(
          title: const Text('Biometric unlock'),
          subtitle: const Text(
            'Use fingerprint/face if available on this device.',
          ),
          value: bio,
          onChanged: (v) async {
            await _auth.setBiometric(v);
            await _refresh();
          },
        ),
      ],
    );
  }
}
