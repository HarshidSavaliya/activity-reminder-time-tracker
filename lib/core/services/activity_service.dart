import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_keys.dart';
import '../database/app_database.dart';
import '../utils/date_time_utils.dart';
import '../utils/recurrence_engine.dart';
import '../../models/activity_model.dart';
import '../../models/enums/activity_category.dart';
import '../../models/enums/activity_priority.dart';
import '../../models/enums/activity_source.dart';
import '../../models/enums/activity_status.dart';
import '../../models/recurrence_rule.dart';
import '../../models/reminder_setting.dart';
import 'storage_service.dart';

/// ActivityService manages CRUD operations for activities scoped strictly per user,
/// handling recurrence exceptions, occurrences, and SQLite persistence.
class ActivityService {
  final StorageService _storage;
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  ActivityService(dynamic storage, [AppDatabase? database])
      : _storage = storage is StorageService
            ? storage
            : (storage is SharedPreferences
                ? SharedPreferencesStorageService(storage)
                : storage as StorageService),
        _db = database ?? AppDatabase.instance;

  String _userKey(String userId) => '${AppKeys.activitiesPrefix}$userId';

  /// Get all raw activity templates for user
  Future<List<ActivityModel>> getActivities(String userId) async {
    // 1. Check SQLite database if active
    if (_db.isOpen) {
      try {
        final dbActivities = await _db.getActivities(userId);
        if (dbActivities.isNotEmpty) {
          return dbActivities;
        }
      } catch (_) {}
    }

    final jsonStr = _storage.getString(_userKey(userId));
    if (jsonStr == null) {
      return await seedInitialActivities(userId);
    }

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      final activities = list
          .map((item) => ActivityModel.fromJson(item as Map<String, dynamic>))
          .toList();
      activities.sort((a, b) => a.startTime.compareTo(b.startTime));
      return activities;
    } catch (_) {
      return [];
    }
  }

  /// Create a new activity
  Future<ActivityModel> createActivity({
    required String userId,
    required String title,
    String description = '',
    required ActivityCategory category,
    required DateTime date,
    required DateTime startTime,
    DateTime? endTime,
    required ActivityPriority priority,
    ActivityStatus status = ActivityStatus.pending,
    ReminderSetting reminder = const ReminderSetting(),
    RecurrenceRule recurrence = const RecurrenceRule(),
    String location = '',
    ActivitySource source = ActivitySource.manual,
  }) async {
    final activity = ActivityModel(
      id: _uuid.v4(),
      userId: userId,
      title: title.trim(),
      description: description.trim(),
      category: category,
      date: date,
      startTime: startTime,
      endTime: endTime,
      priority: priority,
      status: status,
      reminder: reminder,
      recurrence: recurrence,
      location: location.trim(),
      source: source,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final currentActivities = await getActivities(userId);
    final updated = [...currentActivities, activity];
    await _saveAll(userId, updated);
    return activity;
  }

  /// Update an existing activity (entire series)
  Future<ActivityModel> updateActivity(ActivityModel activity) async {
    final currentActivities = await getActivities(activity.userId);
    final index = currentActivities.indexWhere((a) => a.id == activity.id);
    if (index == -1) {
      throw Exception('Activity not found.');
    }

    final updated = List<ActivityModel>.from(currentActivities);
    updated[index] = activity.copyWith(updatedAt: DateTime.now());
    await _saveAll(activity.userId, updated);
    return updated[index];
  }

  /// Delete an activity (entire series)
  Future<void> deleteActivity(String userId, String activityId) async {
    final currentActivities = await getActivities(userId);
    final updated = currentActivities.where((a) => a.id != activityId).toList();
    await _saveAll(userId, updated);
  }

  /// Delete ONLY a single occurrence of a recurring activity
  Future<void> deleteOccurrence(String userId, String parentId, DateTime occurrenceDate) async {
    final currentActivities = await getActivities(userId);
    final index = currentActivities.indexWhere((a) => a.id == parentId);
    if (index == -1) return;

    final parent = currentActivities[index];
    final isoDate = DateTimeUtils.toIsoDateString(occurrenceDate);

    final updatedExcluded = List<String>.from(parent.recurrence.excludedDates);
    if (!updatedExcluded.contains(isoDate)) {
      updatedExcluded.add(isoDate);
    }

    final updatedParent = parent.copyWith(
      recurrence: parent.recurrence.copyWith(excludedDates: updatedExcluded),
      updatedAt: DateTime.now(),
    );

    currentActivities[index] = updatedParent;
    await _saveAll(userId, currentActivities);
  }

  /// Edit ONLY a single occurrence of a recurring activity
  Future<void> editOccurrence(
    String userId,
    String parentId,
    DateTime occurrenceDate,
    Map<String, dynamic> deltaOverrides,
  ) async {
    final currentActivities = await getActivities(userId);
    final index = currentActivities.indexWhere((a) => a.id == parentId);
    if (index == -1) return;

    final parent = currentActivities[index];
    final isoDate = DateTimeUtils.toIsoDateString(occurrenceDate);

    final updatedOverrides =
        Map<String, Map<String, dynamic>>.from(parent.recurrence.occurrenceOverrides);
    final currentOverride = updatedOverrides[isoDate] ?? {};
    updatedOverrides[isoDate] = {...currentOverride, ...deltaOverrides};

    final updatedParent = parent.copyWith(
      recurrence: parent.recurrence.copyWith(occurrenceOverrides: updatedOverrides),
      updatedAt: DateTime.now(),
    );

    currentActivities[index] = updatedParent;
    await _saveAll(userId, currentActivities);
  }

  /// Toggle or update activity status (pending, completed, skipped)
  Future<ActivityModel> updateStatus(
    String userId,
    String activityId,
    ActivityStatus newStatus, {
    DateTime? occurrenceDate,
  }) async {
    final currentActivities = await getActivities(userId);
    final index = currentActivities.indexWhere((a) => a.id == activityId);
    if (index == -1) throw Exception('Activity not found.');

    final current = currentActivities[index];

    // If updating a specific occurrence of a recurring series
    if (occurrenceDate != null && current.isRecurring) {
      await editOccurrence(userId, activityId, occurrenceDate, {
        'status': newStatus.name,
      });
      return RecurrenceEngine.getOccurrenceForDate(
        current.copyWith(
          recurrence: current.recurrence.copyWith(
            occurrenceOverrides: {
              ...current.recurrence.occurrenceOverrides,
              DateTimeUtils.toIsoDateString(occurrenceDate): {'status': newStatus.name},
            },
          ),
        ),
        occurrenceDate,
      );
    }

    // Direct single activity
    final updated = current.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );

    currentActivities[index] = updated;
    await _saveAll(userId, currentActivities);
    return updated;
  }

  /// Reschedule an activity to a new date and time
  Future<ActivityModel> reschedule(
    String userId,
    String activityId,
    DateTime newDate,
    DateTime newStartTime,
    DateTime? newEndTime, {
    DateTime? occurrenceDate,
  }) async {
    final currentActivities = await getActivities(userId);
    final index = currentActivities.indexWhere((a) => a.id == activityId);
    if (index == -1) throw Exception('Activity not found.');

    final current = currentActivities[index];

    if (occurrenceDate != null && current.isRecurring) {
      // Rescheduling a single occurrence
      final delta = {
        'date': newDate.toIso8601String(),
        'startTime': newStartTime.toIso8601String(),
        'endTime': newEndTime?.toIso8601String(),
        'status': ActivityStatus.pending.name,
      };
      await editOccurrence(userId, activityId, occurrenceDate, delta);
      return RecurrenceEngine.getOccurrenceForDate(current, newDate);
    }

    // Rescheduling one-time or whole series anchor
    final updated = current.copyWith(
      date: newDate,
      startTime: newStartTime,
      endTime: newEndTime,
      status: ActivityStatus.pending,
      updatedAt: DateTime.now(),
    );

    currentActivities[index] = updated;
    await _saveAll(userId, currentActivities);
    return updated;
  }

  Future<void> _saveAll(String userId, List<ActivityModel> activities) async {
    final encoded = jsonEncode(activities.map((a) => a.toJson()).toList());
    await _storage.setString(_userKey(userId), encoded);
    try {
      if (_db.isOpen) {
        await _db.replaceUserActivities(userId, activities);
      }
    } catch (_) {}
  }

  /// Seeds realistic initial sample activities for new users (balancing work, routines, fitness, and learning).
  Future<List<ActivityModel>> seedInitialActivities(String userId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final samples = [
      // 1. Operating System (Completed this morning)
      ActivityModel(
        id: _uuid.v4(),
        userId: userId,
        title: 'Operating System',
        description: 'Systems architecture, process synchronization, and concurrency',
        category: ActivityCategory.work,
        date: today,
        startTime: today.add(const Duration(hours: 8, minutes: 30)),
        endTime: today.add(const Duration(hours: 9, minutes: 45)),
        priority: ActivityPriority.medium,
        status: ActivityStatus.completed,
        location: 'Office / Main Workspace',
        source: ActivitySource.manual,
        reminder: const ReminderSetting(minutesBefore: 15),
        recurrence: const RecurrenceRule(
          type: RecurrenceType.custom,
          selectedWeekdays: [1, 2, 3, 4, 5],
        ),
        createdAt: now,
        updatedAt: now,
      ),
      // 2. Data Structures (Up Next today, High Priority)
      ActivityModel(
        id: _uuid.v4(),
        userId: userId,
        title: 'Data Structures',
        description: 'Problem solving and algorithmic performance optimization',
        category: ActivityCategory.study,
        date: today,
        startTime: today.add(const Duration(hours: 10, minutes: 0)),
        endTime: today.add(const Duration(hours: 11, minutes: 0)),
        priority: ActivityPriority.high,
        status: ActivityStatus.pending,
        location: 'Workspace Desk 4',
        source: ActivitySource.manual,
        reminder: const ReminderSetting(minutesBefore: 10),
        recurrence: const RecurrenceRule(
          type: RecurrenceType.custom,
          selectedWeekdays: [1, 2, 3, 4, 5],
        ),
        createdAt: now,
        updatedAt: now,
      ),
      // 3. Hands-on Execution & Development Sprint
      ActivityModel(
        id: _uuid.v4(),
        userId: userId,
        title: 'Development Sprint',
        description: 'Feature implementation and automated integration testing',
        category: ActivityCategory.work,
        date: today,
        startTime: today.add(const Duration(hours: 13, minutes: 30)),
        endTime: today.add(const Duration(hours: 15, minutes: 30)),
        priority: ActivityPriority.high,
        status: ActivityStatus.pending,
        location: 'Focus Pod 3',
        source: ActivitySource.manual,
        reminder: const ReminderSetting(minutesBefore: 15),
        recurrence: const RecurrenceRule(),
        createdAt: now,
        updatedAt: now,
      ),
      // 4. Daily Standup & Project Milestone Review
      ActivityModel(
        id: _uuid.v4(),
        userId: userId,
        title: 'Project Milestone Review',
        description: 'Review project roadmap, deliverables, and sprint blockers',
        category: ActivityCategory.meeting,
        date: today,
        startTime: today.add(const Duration(hours: 17, minutes: 0)),
        endTime: today.add(const Duration(hours: 18, minutes: 0)),
        priority: ActivityPriority.medium,
        status: ActivityStatus.pending,
        location: 'Meeting Room B / Zoom',
        source: ActivitySource.manual,
        reminder: const ReminderSetting(minutesBefore: 30),
        recurrence: const RecurrenceRule(),
        createdAt: now,
        updatedAt: now,
      ),
      // 5. Campus Gym & Fitness Routine (Recurring: Mon, Wed, Fri)
      ActivityModel(
        id: _uuid.v4(),
        userId: userId,
        title: 'Campus Gym',
        description: 'Cardio and strength training routine',
        category: ActivityCategory.personal,
        date: today,
        startTime: today.add(const Duration(hours: 18, minutes: 30)),
        endTime: today.add(const Duration(hours: 19, minutes: 30)),
        priority: ActivityPriority.low,
        status: ActivityStatus.pending,
        location: 'Fitness Center',
        source: ActivitySource.manual,
        reminder: const ReminderSetting(minutesBefore: 15),
        recurrence: const RecurrenceRule(
          type: RecurrenceType.custom,
          selectedWeekdays: [1, 3, 5],
        ),
        createdAt: now,
        updatedAt: now,
      ),
      // 6. Technology & Innovation Seminar (Tomorrow)
      ActivityModel(
        id: _uuid.v4(),
        userId: userId,
        title: 'Technology & AI Seminar',
        description: 'Guest presentation on Intelligent Autonomous Systems',
        category: ActivityCategory.meeting,
        date: today.add(const Duration(days: 1)),
        startTime: today.add(const Duration(days: 1, hours: 11, minutes: 0)),
        endTime: today.add(const Duration(days: 1, hours: 12, minutes: 30)),
        priority: ActivityPriority.low,
        status: ActivityStatus.pending,
        location: 'Auditorium B',
        source: ActivitySource.manual,
        reminder: const ReminderSetting(minutesBefore: 15),
        recurrence: const RecurrenceRule(),
        createdAt: now,
        updatedAt: now,
      ),
    ];

    await _saveAll(userId, samples);
    return samples;
  }

  /// Backwards compatibility alias for college seed test fixtures.
  Future<List<ActivityModel>> seedInitialCollegeActivities(String userId) =>
      seedInitialActivities(userId);

}
