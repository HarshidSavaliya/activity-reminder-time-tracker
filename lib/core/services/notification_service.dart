import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/activity_model.dart';
import '../utils/date_time_utils.dart';
import '../utils/recurrence_engine.dart';
import 'storage_service.dart';

class ScheduledReminder {
  final String id;
  final String activityId;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final bool isTriggered;

  const ScheduledReminder({
    required this.id,
    required this.activityId,
    required this.title,
    required this.body,
    required this.scheduledTime,
    this.isTriggered = false,
  });

  ScheduledReminder copyWith({bool? isTriggered}) {
    return ScheduledReminder(
      id: id,
      activityId: activityId,
      title: title,
      body: body,
      scheduledTime: scheduledTime,
      isTriggered: isTriggered ?? this.isTriggered,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activityId': activityId,
      'title': title,
      'body': body,
      'scheduledTime': scheduledTime.toIso8601String(),
      'isTriggered': isTriggered,
    };
  }

  factory ScheduledReminder.fromJson(Map<String, dynamic> json) {
    return ScheduledReminder(
      id: json['id'] as String,
      activityId: json['activityId'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      scheduledTime: DateTime.parse(json['scheduledTime'] as String),
      isTriggered: json['isTriggered'] as bool? ?? false,
    );
  }
}

/// NotificationService handles reminder scheduling, recurring occurrence alerts,
/// persistence across app restarts, and deterministic notification ID generation.
class NotificationService {
  static const String _storageKey = 'scheduled_activity_reminders';
  final StorageService _storage;

  final StreamController<ScheduledReminder> _reminderStream =
      StreamController<ScheduledReminder>.broadcast();

  Timer? _pollingTimer;
  final bool enableTimer;

  NotificationService(dynamic storage, {this.enableTimer = true})
      : _storage = storage is StorageService
            ? storage
            : (storage is SharedPreferences
                ? SharedPreferencesStorageService(storage)
                : storage as StorageService) {
    _init();
  }

  /// Generates a deterministic strictly positive 31-bit integer for notification alarms,
  /// preventing negative integer exceptions and integer overflow on Android platforms.
  static int generateNotificationId(String id, [int offset = 0]) {
    final raw = (id.hashCode ^ offset).abs() % 0x7FFFFFFF;
    return raw == 0 ? 1 : raw;
  }

  Stream<ScheduledReminder> get onReminderTriggered => _reminderStream.stream;

  void _init() {
    _pruneExpiredReminders();
    if (enableTimer) {
      _startTimer();
    }
  }

  void _startTimer() {
    _pollingTimer?.cancel();
    // Check every 30 seconds for imminent reminders
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkAndDispatchPendingReminders();
    });
  }

  void dispose() {
    _pollingTimer?.cancel();
    _reminderStream.close();
  }

  List<ScheduledReminder> getScheduledReminders() {
    final raw = _storage.getString(_storageKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => ScheduledReminder.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveReminders(List<ScheduledReminder> list) async {
    final encoded = jsonEncode(list.map((r) => r.toJson()).toList());
    await _storage.setString(_storageKey, encoded);
  }

  /// Schedule reminders for an activity. If the activity is recurring,
  /// generates occurrences over the next 14 days and schedules individual reminder alerts.
  Future<void> scheduleRemindersForActivity(ActivityModel activity) async {
    // If reminders disabled or negative minutes
    if (!activity.reminder.isEnabled || activity.reminder.minutesBefore < 0) {
      await cancelRemindersForActivity(activity.id);
      return;
    }

    final now = DateTime.now();
    final reminders = getScheduledReminders().where((r) => r.activityId != activity.id).toList();

    if (!activity.isRecurring) {
      final fireTime = activity.startTime.subtract(Duration(minutes: activity.reminder.minutesBefore));
      if (fireTime.isAfter(now)) {
        reminders.add(
          ScheduledReminder(
            id: '${activity.id}_single',
            activityId: activity.id,
            title: 'Upcoming: ${activity.title}',
            body: _buildBody(activity),
            scheduledTime: fireTime,
          ),
        );
      }
    } else {
      // Recurring: schedule for next 14 days
      final occurrences = RecurrenceEngine.expandForRange(
        [activity],
        now,
        now.add(const Duration(days: 14)),
      );

      for (final occ in occurrences) {
        final fireTime = occ.startTime.subtract(Duration(minutes: activity.reminder.minutesBefore));
        if (fireTime.isAfter(now)) {
          final isoDate = DateTimeUtils.toIsoDateString(occ.date);
          reminders.add(
            ScheduledReminder(
              id: '${activity.id}_$isoDate',
              activityId: activity.id,
              title: 'Upcoming: ${occ.title}',
              body: _buildBody(occ),
              scheduledTime: fireTime,
            ),
          );
        }
      }
    }

    await _saveReminders(reminders);
  }

  String _buildBody(ActivityModel activity) {
    final timeStr = DateTimeUtils.formatTime(activity.startTime);
    final reminderText = activity.reminder.minutesBefore == 0
        ? 'starts now'
        : 'in ${activity.reminder.minutesBefore} mins';
    if (activity.location.isNotEmpty) {
      return '$reminderText ($timeStr) at ${activity.location}';
    }
    return '$reminderText ($timeStr)';
  }

  /// Cancel all reminders for an activity
  Future<void> cancelRemindersForActivity(String activityId) async {
    final current = getScheduledReminders();
    final filtered = current.where((r) => r.activityId != activityId).toList();
    await _saveReminders(filtered);
  }

  /// Check pending reminders and trigger active alerts
  void checkAndDispatchPendingReminders() {
    final now = DateTime.now();
    final all = getScheduledReminders();
    bool changed = false;

    final updated = <ScheduledReminder>[];

    for (final reminder in all) {
      if (!reminder.isTriggered && reminder.scheduledTime.isBefore(now)) {
        _reminderStream.add(reminder);
        updated.add(reminder.copyWith(isTriggered: true));
        changed = true;
        if (kDebugMode) {
          print('Reminder Dispatched: ${reminder.title} - ${reminder.body}');
        }
      } else {
        updated.add(reminder);
      }
    }

    if (changed) {
      _saveReminders(updated);
    }
  }

  /// Prune reminders older than 48 hours to prevent unbounded memory
  void _pruneExpiredReminders() {
    final cutoff = DateTime.now().subtract(const Duration(days: 2));
    final current = getScheduledReminders();
    final pruned = current.where((r) => r.scheduledTime.isAfter(cutoff)).toList();
    _saveReminders(pruned);
  }
}
