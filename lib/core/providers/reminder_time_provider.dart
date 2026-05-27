import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/settings_service.dart';
import 'settings_provider.dart';

const _kReminderTime = 'reminder.time'; // "HH:mm"

class ReminderTimeNotifier extends StateNotifier<TimeOfDay> {
  ReminderTimeNotifier(this._settings)
      : super(const TimeOfDay(hour: 9, minute: 0)) {
    unawaited(_load());
  }

  final SettingsService _settings;

  Future<void> _load() async {
    final raw = await _settings.getRaw(_kReminderTime);
    if (raw == null) return;
    final parts = raw.split(':');
    if (parts.length != 2) return;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return;
    state = TimeOfDay(hour: h, minute: m);
  }

  Future<void> setTime(TimeOfDay value) async {
    state = value;
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    await _settings.setRaw(_kReminderTime, '$h:$m');
  }
}

final reminderTimeProvider =
    StateNotifierProvider<ReminderTimeNotifier, TimeOfDay>((ref) {
  return ReminderTimeNotifier(ref.watch(settingsServiceProvider));
});
