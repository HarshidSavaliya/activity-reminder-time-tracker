import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/activity_service.dart';
import '../core/services/notification_service.dart';
import '../core/utils/conflict_resolution_engine.dart';
import '../core/utils/recurrence_engine.dart';
import '../models/activity_model.dart';
import '../models/enums/activity_category.dart';
import '../models/enums/activity_priority.dart';
import '../models/enums/activity_source.dart';
import '../models/enums/activity_status.dart';
import '../models/recurrence_rule.dart';
import '../models/reminder_setting.dart';

enum ActivitySortBy { time, priority, recent }
enum ActivityRecurrenceFilter { all, recurringOnly, oneTimeOnly }

/// Real-time weekly task statistics model for dynamic dashboard charts
class WeeklyActivityStats {
  final List<double> progress;
  final List<double> review;
  final List<double> complete;
  final double maxY;
  final int totalCount;

  const WeeklyActivityStats({
    required this.progress,
    required this.review,
    required this.complete,
    required this.maxY,
    required this.totalCount,
  });
}

/// ActivityProvider coordinates state, filters, sorting, overlap detection,
/// and recurrence occurrences across the application.
class ActivityProvider extends ChangeNotifier {
  final ActivityService _activityService;
  final NotificationService? _notificationService;

  List<ActivityModel> _activities = [];
  bool _isLoading = false;
  String? _errorMessage;

  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  ActivityCategory? _selectedCategory;
  ActivityPriority? _selectedPriority;
  ActivityStatus? _selectedStatus;
  ActivityRecurrenceFilter _recurrenceFilter = ActivityRecurrenceFilter.all;
  ActivitySortBy _sortBy = ActivitySortBy.time;
  bool _hideCompleted = true;

  ActivityProvider(this._activityService, [this._notificationService]) {
    _initPreferences();
  }

  Future<void> _initPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hideCompleted = prefs.getBool('app_hide_completed') ?? true;
      notifyListeners();
    } catch (_) {}
  }

  List<ActivityModel> get activities => _activities;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime get selectedDate => _selectedDate;
  String get searchQuery => _searchQuery;
  ActivityCategory? get selectedCategory => _selectedCategory;
  ActivityPriority? get selectedPriority => _selectedPriority;
  ActivityStatus? get selectedStatus => _selectedStatus;
  ActivityRecurrenceFilter get recurrenceFilter => _recurrenceFilter;
  ActivitySortBy get sortBy => _sortBy;
  bool get hideCompleted => _hideCompleted;

  Future<void> setHideCompleted(bool value) async {
    if (_hideCompleted == value) return;
    _hideCompleted = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_hide_completed', value);
    } catch (_) {}
  }

  Future<void> toggleHideCompleted() async {
    await setHideCompleted(!_hideCompleted);
  }

  // MARK: - Computed Occurrences

  /// All today's activity occurrences (both completed and pending)
  List<ActivityModel> get allTodayActivities {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final occurrences = RecurrenceEngine.expandForRange(_activities, today, today);
    return _applySort(occurrences);
  }

  /// Active today's activities. If [hideCompleted] is true, completed activities are hidden.
  List<ActivityModel> get todayActivities {
    final all = allTodayActivities;
    if (_hideCompleted) {
      return all.where((a) => !a.isCompleted).toList();
    }
    return all;
  }

  /// Today stats (evaluated over all occurrences so completion ratios stay accurate)
  int get todayTotalCount => allTodayActivities.length;
  int get todayCompletedCount =>
      allTodayActivities.where((a) => a.status == ActivityStatus.completed).length;
  int get todayPendingCount =>
      allTodayActivities.where((a) => a.status == ActivityStatus.pending).length;
  double get todayCompletionRate =>
      todayTotalCount == 0 ? 0.0 : (todayCompletedCount / todayTotalCount);

  /// Computes dynamic weekly statistics for the week surrounding anchor (Monday to Sunday)
  WeeklyActivityStats getWeeklyStats([DateTime? anchor]) {
    final base = anchor ?? DateTime.now();
    final weekday = base.weekday; // 1 = Monday, 7 = Sunday
    final monday = base.subtract(Duration(days: weekday - 1));
    final start = DateTime(monday.year, monday.month, monday.day);
    final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    final occurrences = RecurrenceEngine.expandForRange(_activities, start, end);

    final progress = List<double>.filled(7, 0.0);
    final review = List<double>.filled(7, 0.0);
    final complete = List<double>.filled(7, 0.0);

    for (final act in occurrences) {
      final dayIndex = (act.date.weekday - 1).clamp(0, 6);
      if (act.isCompleted) {
        complete[dayIndex] += 1;
      } else {
        progress[dayIndex] += 1;
      }
      if (act.priority == ActivityPriority.high ||
          act.category == ActivityCategory.study ||
          act.category == ActivityCategory.exam) {
        review[dayIndex] += 1;
      }
    }

    double maxVal = 0;
    for (int i = 0; i < 7; i++) {
      if (progress[i] > maxVal) maxVal = progress[i];
      if (review[i] > maxVal) maxVal = review[i];
      if (complete[i] > maxVal) maxVal = complete[i];
    }

    // Determine clean rounded maxY
    double computedMaxY;
    if (maxVal <= 5) {
      computedMaxY = 5.0;
    } else if (maxVal <= 10) {
      computedMaxY = 10.0;
    } else if (maxVal <= 25) {
      computedMaxY = 25.0;
    } else {
      computedMaxY = ((maxVal / 10).ceil() * 10).toDouble();
    }

    return WeeklyActivityStats(
      progress: progress,
      review: review,
      complete: complete,
      maxY: computedMaxY,
      totalCount: occurrences.length,
    );
  }

  /// Imminent next activity for today
  ActivityModel? get upNextActivity {
    final now = DateTime.now();

    final todayPending = todayActivities.where((a) {
      if (a.isCompleted || a.isSkipped) return false;
      final effectiveEnd = a.endTime ?? a.startTime.add(const Duration(minutes: 50));
      return effectiveEnd.isAfter(now);
    }).toList();

    if (todayPending.isNotEmpty) {
      return todayPending.first;
    }

    final anyToday = todayActivities.where((a) => !a.isCompleted && !a.isSkipped).toList();
    if (anyToday.isNotEmpty) {
      return anyToday.first;
    }

    return null;
  }

  /// Overdue / Missed activities: scheduled earlier today or past days and still pending
  List<ActivityModel> get overdueActivities {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final windowStart = today.subtract(const Duration(days: 7));
    final occurrences = RecurrenceEngine.expandForRange(_activities, windowStart, today);

    return occurrences.where((a) {
      if (a.isCompleted || a.isSkipped) return false;
      final effectiveEnd = a.endTime ?? a.startTime.add(const Duration(minutes: 45));
      return effectiveEnd.isBefore(now);
    }).toList();
  }

  /// Evaluates day occurrences for calendar or date selection
  List<ActivityModel> getOccurrencesForDate(DateTime date) {
    final targetDay = DateTime(date.year, date.month, date.day);
    final occurrences = RecurrenceEngine.expandForRange(_activities, targetDay, targetDay);
    return _applySort(occurrences);
  }

  /// Evaluates month occurrences for calendar day dot indicators
  Map<DateTime, List<ActivityModel>> getOccurrencesForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final expanded = RecurrenceEngine.expandForRange(_activities, start, end);
    final map = <DateTime, List<ActivityModel>>{};

    for (final act in expanded) {
      final key = DateTime(act.date.year, act.date.month, act.date.day);
      map.putIfAbsent(key, () => []).add(act);
    }
    return map;
  }

  /// Activities for selected date
  List<ActivityModel> get activitiesForSelectedDate => filteredActivities;

  /// Count of scheduled activities for a specific date
  int countForDate(DateTime date) => getOccurrencesForDate(date).length;

  /// Weekly activities for timetable view
  List<ActivityModel> getActivitiesForWeek(DateTime anchor) {
    final weekday = anchor.weekday;
    final monday = anchor.subtract(Duration(days: weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return RecurrenceEngine.expandForRange(_activities, monday, sunday);
  }

  /// High priority activities among today's routine
  List<ActivityModel> get highPriorityActivities =>
      todayActivities.where((a) => a.priority == ActivityPriority.high).toList();

  /// Pending activities among today's routine
  List<ActivityModel> get pendingActivities =>
      todayActivities.where((a) => a.status == ActivityStatus.pending).toList();

  /// Completed activities among today's routine
  List<ActivityModel> get completedActivities =>
      allTodayActivities.where((a) => a.status == ActivityStatus.completed).toList();

  /// Overlap collision check delegating to ConflictResolutionEngine
  ActivityModel? checkOverlap({
    required DateTime date,
    required DateTime startTime,
    DateTime? endTime,
    String? excludeActivityId,
  }) {
    return ConflictResolutionEngine.findFirstConflict(
      existingActivities: _activities,
      date: date,
      startTime: startTime,
      endTime: endTime,
      excludeActivityId: excludeActivityId,
    );
  }


  /// Filtered and sorted activities based on currently active UI filters
  List<ActivityModel> get filteredActivities {
    final targetDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final occurrences = RecurrenceEngine.expandForRange(_activities, targetDay, targetDay);

    final filtered = occurrences.where((activity) {
      if (_hideCompleted && _selectedStatus == null && activity.isCompleted) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = activity.title.toLowerCase().contains(q);
        final matchDesc = activity.description.toLowerCase().contains(q);
        final matchLocation = activity.location.toLowerCase().contains(q);
        if (!matchTitle && !matchDesc && !matchLocation) return false;
      }

      if (_selectedCategory != null && activity.category != _selectedCategory) {
        return false;
      }

      if (_selectedPriority != null && activity.priority != _selectedPriority) {
        return false;
      }

      if (_selectedStatus != null && activity.status != _selectedStatus) {
        return false;
      }

      if (_recurrenceFilter == ActivityRecurrenceFilter.recurringOnly && !activity.isRecurring) {
        return false;
      }
      if (_recurrenceFilter == ActivityRecurrenceFilter.oneTimeOnly && activity.isRecurring) {
        return false;
      }

      return true;
    }).toList();

    return _applySort(filtered);
  }

  // MARK: - Overlap & Conflict Checkers

  bool hasConflict({
    required DateTime date,
    required DateTime startTime,
    required DateTime? endTime,
    String? excludeActivityId,
  }) {
    return ConflictResolutionEngine.findFirstConflict(
          existingActivities: _activities,
          date: date,
          startTime: startTime,
          endTime: endTime,
          excludeActivityId: excludeActivityId,
        ) !=
        null;
  }

  ActivityModel? getConflictingActivity({
    required DateTime date,
    required DateTime startTime,
    required DateTime? endTime,
    String? excludeActivityId,
  }) {
    return ConflictResolutionEngine.findFirstConflict(
      existingActivities: _activities,
      date: date,
      startTime: startTime,
      endTime: endTime,
      excludeActivityId: excludeActivityId,
    );
  }

  ConflictCheckResult checkConflictDetails({
    required DateTime date,
    required DateTime startTime,
    required DateTime? endTime,
    String? excludeActivityId,
  }) {
    return ConflictResolutionEngine.checkConflict(
      existingActivities: _activities,
      date: date,
      startTime: startTime,
      endTime: endTime,
      excludeActivityId: excludeActivityId,
    );
  }

  // MARK: - Sorting Helper

  List<ActivityModel> _applySort(List<ActivityModel> items) {
    final sorted = List<ActivityModel>.from(items);
    switch (_sortBy) {
      case ActivitySortBy.time:
        sorted.sort((a, b) => a.startTime.compareTo(b.startTime));
        break;
      case ActivitySortBy.priority:
        sorted.sort((a, b) {
          final pA = _priorityScore(a.priority);
          final pB = _priorityScore(b.priority);
          return pB.compareTo(pA);
        });
        break;
      case ActivitySortBy.recent:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return sorted;
  }

  int _priorityScore(ActivityPriority priority) {
    switch (priority) {
      case ActivityPriority.high:
        return 3;
      case ActivityPriority.medium:
        return 2;
      case ActivityPriority.low:
        return 1;
    }
  }

  // MARK: - Actions

  Future<void> loadActivities(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _activities = await _activityService.getActivities(userId);
      _isLoading = false;
      notifyListeners();

      if (_notificationService != null) {
        for (final act in _activities) {
          await _notificationService.scheduleRemindersForActivity(act);
        }
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshActivities(String userId) async {
    try {
      _activities = await _activityService.getActivities(userId);
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> createActivity({
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
    try {
      final newActivity = await _activityService.createActivity(
        userId: userId,
        title: title,
        description: description,
        category: category,
        date: date,
        startTime: startTime,
        endTime: endTime,
        priority: priority,
        status: status,
        reminder: reminder,
        recurrence: recurrence,
        location: location,
        source: source,
      );

      _activities = [..._activities, newActivity]
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      notifyListeners();

      await _notificationService?.scheduleRemindersForActivity(newActivity);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateActivity(ActivityModel activity) async {
    try {
      final updated = await _activityService.updateActivity(activity);
      final index = _activities.indexWhere((a) => a.id == updated.id);
      if (index != -1) {
        _activities[index] = updated;
        _activities.sort((a, b) => a.startTime.compareTo(b.startTime));
        notifyListeners();
      }

      await _notificationService?.scheduleRemindersForActivity(updated);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteActivity(String userId, String activityId) async {
    try {
      await _activityService.deleteActivity(userId, activityId);
      _activities.removeWhere((a) => a.id == activityId);
      notifyListeners();

      await _notificationService?.cancelRemindersForActivity(activityId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteOccurrence(String userId, String parentId, DateTime occurrenceDate) async {
    try {
      await _activityService.deleteOccurrence(userId, parentId, occurrenceDate);
      await refreshActivities(userId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> editOccurrence(
    String userId,
    String parentId,
    DateTime occurrenceDate,
    Map<String, dynamic> deltaOverrides,
  ) async {
    try {
      await _activityService.editOccurrence(userId, parentId, occurrenceDate, deltaOverrides);
      await refreshActivities(userId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleCompletion(
    String userId,
    String activityId, {
    DateTime? occurrenceDate,
  }) async {
    try {
      ActivityStatus currentStatus = ActivityStatus.pending;
      final parent = _activities.firstWhere(
        (a) => a.id == activityId,
        orElse: () => _activities.first,
      );

      if (occurrenceDate != null && parent.isRecurring) {
        final occ = RecurrenceEngine.getOccurrenceForDate(parent, occurrenceDate);
        currentStatus = occ.status;
      } else {
        currentStatus = parent.status;
      }

      final nextStatus = currentStatus == ActivityStatus.completed
          ? ActivityStatus.pending
          : ActivityStatus.completed;

      await _activityService.updateStatus(
        userId,
        activityId,
        nextStatus,
        occurrenceDate: occurrenceDate,
      );

      await refreshActivities(userId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> markStatus(
    String userId,
    String activityId,
    ActivityStatus status, {
    DateTime? occurrenceDate,
  }) async {
    try {
      await _activityService.updateStatus(
        userId,
        activityId,
        status,
        occurrenceDate: occurrenceDate,
      );
      await refreshActivities(userId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  Future<bool> rescheduleActivity(
    String userId,
    String activityId,
    DateTime newDate,
    DateTime newStartTime,
    DateTime? newEndTime, {
    DateTime? occurrenceDate,
  }) async {
    try {
      final updated = await _activityService.reschedule(
        userId,
        activityId,
        newDate,
        newStartTime,
        newEndTime,
        occurrenceDate: occurrenceDate,
      );

      await refreshActivities(userId);
      await _notificationService?.scheduleRemindersForActivity(updated);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // MARK: - Filters & Search Setters

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategoryFilter(ActivityCategory? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setPriorityFilter(ActivityPriority? priority) {
    _selectedPriority = priority;
    notifyListeners();
  }

  void setStatusFilter(ActivityStatus? status) {
    _selectedStatus = status;
    notifyListeners();
  }

  void setRecurrenceFilter(ActivityRecurrenceFilter filter) {
    _recurrenceFilter = filter;
    notifyListeners();
  }

  void setSortBy(ActivitySortBy sort) {
    _sortBy = sort;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _selectedPriority = null;
    _selectedStatus = null;
    _recurrenceFilter = ActivityRecurrenceFilter.all;
    _sortBy = ActivitySortBy.time;
    notifyListeners();
  }
}

/// Backwards compatibility alias
typedef ActivityController = ActivityProvider;
