import 'enums/activity_category.dart';
import 'enums/activity_priority.dart';
import 'enums/activity_source.dart';
import 'enums/activity_status.dart';
import 'recurrence_rule.dart';
import 'reminder_setting.dart';

/// ActivityModel represents an academic lecture, lab, assignment, or personal routine task.
class ActivityModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final ActivityCategory category;
  final DateTime date; // Anchor calendar date
  final DateTime startTime;
  final DateTime? endTime;
  final ActivityPriority priority;
  final ActivityStatus status;
  final ReminderSetting reminder;
  final RecurrenceRule recurrence;
  final String location;
  final ActivitySource source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  // Occurrence metadata (when generated on the fly for recurring instances)
  final String? recurrenceParentId;
  final DateTime? occurrenceDate;

  ActivityModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    required this.category,
    required this.date,
    required this.startTime,
    this.endTime,
    required this.priority,
    this.status = ActivityStatus.pending,
    this.reminder = const ReminderSetting(),
    this.recurrence = const RecurrenceRule(),
    this.location = '',
    this.source = ActivitySource.manual,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
    this.recurrenceParentId,
    this.occurrenceDate,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Convenience getters for UI components & backwards compatibility
  DateTime get dateTime => startTime;
  bool get isCompleted => status == ActivityStatus.completed;
  bool get isSkipped => status == ActivityStatus.skipped;
  bool get isRecurring => recurrence.isRecurring;
  int get reminderMinutesBefore => reminder.minutesBefore;

  /// Check whether the activity is overdue/missed (past scheduled time while still pending)
  bool get isOverdue {
    if (status == ActivityStatus.completed || status == ActivityStatus.skipped) {
      return false;
    }
    final now = DateTime.now();
    final effectiveEnd = endTime ?? startTime.add(const Duration(minutes: 45));
    return effectiveEnd.isBefore(now);
  }

  ActivityModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    ActivityCategory? category,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    ActivityPriority? priority,
    ActivityStatus? status,
    ReminderSetting? reminder,
    RecurrenceRule? recurrence,
    String? location,
    ActivitySource? source,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? recurrenceParentId,
    DateTime? occurrenceDate,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      reminder: reminder ?? this.reminder,
      recurrence: recurrence ?? this.recurrence,
      location: location ?? this.location,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      recurrenceParentId: recurrenceParentId ?? this.recurrenceParentId,
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'category': category.name,
      'date': date.toIso8601String(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'priority': priority.name,
      'status': status.name,
      'reminder': reminder.toJson(),
      'recurrence': recurrence.toJson(),
      'location': location,
      'source': source.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'recurrenceParentId': recurrenceParentId,
      'occurrenceDate': occurrenceDate?.toIso8601String(),
    };
  }

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    // Backward compatibility parsing for Phase 1 fields:
    final startDt = json['startTime'] != null
        ? DateTime.parse(json['startTime'] as String)
        : (json['dateTime'] != null
            ? DateTime.parse(json['dateTime'] as String)
            : DateTime.now());

    final dateAnchor = json['date'] != null
        ? DateTime.parse(json['date'] as String)
        : DateTime(startDt.year, startDt.month, startDt.day);

    final legacyIsCompleted = json['isCompleted'] as bool? ?? false;
    final parsedStatus = json['status'] != null
        ? ActivityStatus.fromString(json['status'] as String?)
        : (legacyIsCompleted ? ActivityStatus.completed : ActivityStatus.pending);

    ReminderSetting parsedReminder;
    if (json['reminder'] is Map<String, dynamic>) {
      parsedReminder = ReminderSetting.fromJson(json['reminder'] as Map<String, dynamic>);
    } else if (json['reminderMinutesBefore'] is int) {
      parsedReminder = ReminderSetting(
        minutesBefore: json['reminderMinutesBefore'] as int,
        isEnabled: (json['reminderMinutesBefore'] as int) > 0,
      );
    } else {
      parsedReminder = const ReminderSetting();
    }

    RecurrenceRule parsedRecurrence;
    if (json['recurrence'] is Map<String, dynamic>) {
      parsedRecurrence = RecurrenceRule.fromJson(json['recurrence'] as Map<String, dynamic>);
    } else if (json['isRecurring'] == true) {
      final rule = json['recurrenceRule'] as String?;
      if (rule == 'daily') {
        parsedRecurrence = const RecurrenceRule(type: RecurrenceType.daily);
      } else if (rule == 'weekly') {
        parsedRecurrence = const RecurrenceRule(type: RecurrenceType.weekly);
      } else if (rule == 'weekdays') {
        parsedRecurrence = const RecurrenceRule(
          type: RecurrenceType.custom,
          selectedWeekdays: [1, 2, 3, 4, 5],
        );
      } else {
        parsedRecurrence = const RecurrenceRule(type: RecurrenceType.daily);
      }
    } else {
      parsedRecurrence = const RecurrenceRule();
    }

    return ActivityModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: ActivityCategory.fromString(json['category'] as String?),
      date: dateAnchor,
      startTime: startDt,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
      priority: ActivityPriority.fromString(json['priority'] as String?),
      status: parsedStatus,
      reminder: parsedReminder,
      recurrence: parsedRecurrence,
      location: json['location'] as String? ?? '',
      source: ActivitySource.fromString(json['source'] as String?),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      recurrenceParentId: json['recurrenceParentId'] as String?,
      occurrenceDate: json['occurrenceDate'] != null
          ? DateTime.parse(json['occurrenceDate'] as String)
          : null,
    );
  }
}
