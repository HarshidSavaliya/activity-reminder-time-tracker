enum RecurrenceType {
  never('Never (One-time)'),
  daily('Every day'),
  weekly('Every week'),
  monthly('Every month'),
  custom('Custom recurrence');

  static const RecurrenceType none = RecurrenceType.never;

  final String label;
  const RecurrenceType(this.label);

  static RecurrenceType fromString(String? value) {
    if (value == null) return RecurrenceType.never;
    if (value.toLowerCase() == 'none') return RecurrenceType.never;
    return RecurrenceType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => RecurrenceType.never,
    );
  }
}

/// RecurrenceRule defines pattern intervals, weekday subsets, termination bounds,
/// and tracks deleted or modified individual occurrences.
class RecurrenceRule {
  final RecurrenceType type;
  final int interval; // Every N days/weeks/months
  final List<int> selectedWeekdays; // 1 = Monday ... 7 = Sunday
  final DateTime? startDate;
  final DateTime? endDate;
  final int? maxOccurrences;
  final List<String> excludedDates; // ISO strings (yyyy-MM-dd) of deleted occurrences
  final Map<String, Map<String, dynamic>> occurrenceOverrides; // ISO string -> json delta

  const RecurrenceRule({
    this.type = RecurrenceType.never,
    this.interval = 1,
    this.selectedWeekdays = const [],
    this.startDate,
    this.endDate,
    this.maxOccurrences,
    this.excludedDates = const [],
    this.occurrenceOverrides = const {},
  });

  bool get isRecurring => type != RecurrenceType.never;

  String get summary {
    switch (type) {
      case RecurrenceType.never:
        return 'Never';
      case RecurrenceType.daily:
        return interval == 1 ? 'Every day' : 'Every $interval days';
      case RecurrenceType.weekly:
        if (selectedWeekdays.isEmpty) {
          return interval == 1 ? 'Every week' : 'Every $interval weeks';
        }
        final dayNames = selectedWeekdays.map(_weekdayShortName).join(', ');
        return 'Every $dayNames';
      case RecurrenceType.monthly:
        return interval == 1 ? 'Every month' : 'Every $interval months';
      case RecurrenceType.custom:
        if (selectedWeekdays.isNotEmpty) {
          final dayNames = selectedWeekdays.map(_weekdayShortName).join(', ');
          return 'Every $dayNames (every $interval ${interval == 1 ? "week" : "weeks"})';
        }
        return 'Custom ($interval)';
    }
  }

  static String _weekdayShortName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  RecurrenceRule copyWith({
    RecurrenceType? type,
    int? interval,
    List<int>? selectedWeekdays,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? excludedDates,
    Map<String, Map<String, dynamic>>? occurrenceOverrides,
  }) {
    return RecurrenceRule(
      type: type ?? this.type,
      interval: interval ?? this.interval,
      selectedWeekdays: selectedWeekdays ?? this.selectedWeekdays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      excludedDates: excludedDates ?? this.excludedDates,
      occurrenceOverrides: occurrenceOverrides ?? this.occurrenceOverrides,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'interval': interval,
      'selectedWeekdays': selectedWeekdays,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'excludedDates': excludedDates,
      'occurrenceOverrides': occurrenceOverrides,
    };
  }

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    return RecurrenceRule(
      type: RecurrenceType.fromString(json['type'] as String?),
      interval: json['interval'] as int? ?? 1,
      selectedWeekdays: (json['selectedWeekdays'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      excludedDates: (json['excludedDates'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      occurrenceOverrides: (json['occurrenceOverrides'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map))) ??
          const {},
    );
  }
}
