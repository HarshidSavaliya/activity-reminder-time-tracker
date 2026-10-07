import 'enums/activity_category.dart';
import 'enums/activity_priority.dart';
import 'recurrence_rule.dart';

enum ExtractionConfidence {
  high,
  medium,
  low,
}

/// Represents an activity candidate extracted from a PDF schedule.
/// Allows the user to inspect, modify, resolve duplicates, and approve before import.
class ExtractedActivityDraft {
  String id;
  String title;
  String description;
  String location;
  String? faculty;
  String? department;
  String? semester;
  ActivityCategory category;
  ActivityPriority priority;
  int weekday; // 1 = Monday, 7 = Sunday
  DateTime? specificDate;
  int startHour;
  int startMinute;
  int endHour;
  int endMinute;
  RecurrenceRule recurrence;
  ExtractionConfidence confidence;
  List<String> confidenceNotes;
  bool isDuplicate;
  String? duplicateReason;
  bool isSelected;

  ExtractedActivityDraft({
    required this.id,
    required this.title,
    this.description = '',
    this.location = '',
    this.faculty,
    this.department,
    this.semester,
    this.category = ActivityCategory.lecture,
    this.priority = ActivityPriority.medium,
    int? weekday,
    int? dayOfWeek,
    this.specificDate,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    DateTime? startTime,
    DateTime? endTime,
    RecurrenceRule? recurrence,
    this.confidence = ExtractionConfidence.high,
    List<String>? confidenceNotes,
    this.isDuplicate = false,
    this.duplicateReason,
    this.isSelected = true,
  })  : weekday = weekday ?? dayOfWeek ?? (specificDate?.weekday ?? (startTime?.weekday ?? 1)),
        startHour = startHour ?? (startTime?.hour ?? 9),
        startMinute = startMinute ?? (startTime?.minute ?? 0),
        endHour = endHour ?? (endTime?.hour ?? 10),
        endMinute = endMinute ?? (endTime?.minute ?? 0),
        recurrence = recurrence ?? const RecurrenceRule(type: RecurrenceType.weekly),
        confidenceNotes = confidenceNotes ?? [];

  int get dayOfWeek => weekday;
  set dayOfWeek(int val) => weekday = val;

  DateTime get startTime {
    final base = specificDate ?? DateTime.now();
    return DateTime(base.year, base.month, base.day, startHour, startMinute);
  }

  DateTime get endTime {
    final base = specificDate ?? DateTime.now();
    return DateTime(base.year, base.month, base.day, endHour, endMinute);
  }

  bool get isRecurring => recurrence.isRecurring;

  String get timeRange {
    final sH = startHour.toString().padLeft(2, '0');
    final sM = startMinute.toString().padLeft(2, '0');
    final eH = endHour.toString().padLeft(2, '0');
    final eM = endMinute.toString().padLeft(2, '0');
    return '$sH:$sM - $eH:$eM';
  }

  bool get hasConflict => isDuplicate || confidenceNotes.any((n) => n.toLowerCase().contains('conflict'));

  bool get isIncomplete =>
      title.trim().isEmpty ||
      (startHour == 0 && endHour == 0 && startMinute == 0 && endMinute == 0) ||
      (startHour == endHour && startMinute == endMinute);

  bool get isReady => !hasConflict && !isIncomplete;

  String get dayName {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Monday';
    }
  }

  String get timeFormatted {
    final sH = startHour == 0 ? 12 : (startHour > 12 ? startHour - 12 : startHour);
    final sAm = startHour >= 12 ? 'PM' : 'AM';
    final sM = startMinute.toString().padLeft(2, '0');

    final eH = endHour == 0 ? 12 : (endHour > 12 ? endHour - 12 : endHour);
    final eAm = endHour >= 12 ? 'PM' : 'AM';
    final eM = endMinute.toString().padLeft(2, '0');

    return '$sH:$sM $sAm - $eH:$eM $eAm';
  }

  ExtractedActivityDraft copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    String? faculty,
    String? department,
    String? semester,
    ActivityCategory? category,
    ActivityPriority? priority,
    int? weekday,
    int? dayOfWeek,
    DateTime? specificDate,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    DateTime? startTime,
    DateTime? endTime,
    RecurrenceRule? recurrence,
    ExtractionConfidence? confidence,
    List<String>? confidenceNotes,
    bool? isDuplicate,
    String? duplicateReason,
    bool? isSelected,
  }) {
    return ExtractedActivityDraft(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      faculty: faculty ?? this.faculty,
      department: department ?? this.department,
      semester: semester ?? this.semester,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      weekday: weekday ?? dayOfWeek ?? this.weekday,
      specificDate: specificDate ?? this.specificDate,
      startHour: startHour ?? (startTime?.hour ?? this.startHour),
      startMinute: startMinute ?? (startTime?.minute ?? this.startMinute),
      endHour: endHour ?? (endTime?.hour ?? this.endHour),
      endMinute: endMinute ?? (endTime?.minute ?? this.endMinute),
      recurrence: recurrence ?? this.recurrence,
      confidence: confidence ?? this.confidence,
      confidenceNotes: confidenceNotes ?? List.from(this.confidenceNotes),
      isDuplicate: isDuplicate ?? this.isDuplicate,
      duplicateReason: duplicateReason ?? this.duplicateReason,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
