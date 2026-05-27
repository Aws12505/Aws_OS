import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../db/app_database.dart';

/// Wraps flutter_local_notifications with the project's reminder logic:
/// for every pending scheduled occurrence, schedule notifications at the
/// user's configured time of day, starting 1 day before the due date and
/// repeating daily for up to 30 days after due — until the user confirms
/// or skips the occurrence (which cancels them).
class NotificationService {
  NotificationService();

  static const String _channelId = 'reminders';
  static const String _channelName = 'Reminders';
  static const String _channelDesc =
      'Scheduled income & expense reminders, repeating until you act.';
  static const int _daysBefore = 1;
  static const int _daysAfter = 30;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: android);
    await _plugin.initialize(settings: init);

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
        ),
      );
      await androidImpl.requestNotificationsPermission();
      await androidImpl.requestExactAlarmsPermission();
    }
    _initialized = true;
  }

  Future<void> scheduleForOccurrence(
    ScheduledOccurrence occurrence, {
    required int reminderHour,
    required int reminderMinute,
    required String preview,
  }) async {
    final due = occurrence.dueAt;
    final base = DateTime(due.year, due.month, due.day, reminderHour,
        reminderMinute);
    final now = DateTime.now();

    for (int offset = -_daysBefore; offset <= _daysAfter; offset++) {
      final fireAt = base.add(Duration(days: offset));
      if (fireAt.isBefore(now)) continue;
      final id = _notificationId(occurrence.id, offset);
      final title = offset < 0
          ? 'Upcoming tomorrow'
          : (offset == 0 ? 'Due today' : 'Still pending');
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: preview,
          scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDesc,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'occurrence:${occurrence.id}',
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to schedule notification: $e');
        }
      }
    }
  }

  Future<void> cancelForOccurrence(String occurrenceId) async {
    for (int offset = -_daysBefore; offset <= _daysAfter; offset++) {
      await _plugin.cancel(id: _notificationId(occurrenceId, offset));
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  int _notificationId(String occurrenceId, int dayOffset) {
    // Combine a stable hash of the UUID with the offset, masked to 31 bits.
    final base = occurrenceId.hashCode;
    return ((base ^ (dayOffset * 1315423911)) & 0x7FFFFFFF);
  }
}
