import '../../models/activity_model.dart';
import '../../models/recurrence_rule.dart';
import 'date_time_utils.dart';

/// RecurrenceEngine safely calculates and generates occurrences for recurring activities
/// without polluting storage with infinite instances.
class RecurrenceEngine {
  RecurrenceEngine._();

  /// Determines if an activity has an occurrence on [targetDate].
  static bool occursOnDate(ActivityModel activity, DateTime targetDate) {
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final anchor = DateTime(activity.date.year, activity.date.month, activity.date.day);
    final isoDate = DateTimeUtils.toIsoDateString(target);

    // If deleted specifically for this occurrence
    if (activity.recurrence.excludedDates.contains(isoDate)) {
      return false;
    }

    // One-time activity
    if (!activity.recurrence.isRecurring) {
      return target == anchor;
    }

    // Recurring activity cannot happen before its anchor/start date
    final effectiveStart = activity.recurrence.startDate != null
        ? DateTime(activity.recurrence.startDate!.year, activity.recurrence.startDate!.month,
            activity.recurrence.startDate!.day)
        : anchor;

    if (target.isBefore(effectiveStart)) {
      return false;
    }

    // Cannot happen after end date (if specified)
    if (activity.recurrence.endDate != null) {
      final effectiveEnd = DateTime(activity.recurrence.endDate!.year,
          activity.recurrence.endDate!.month, activity.recurrence.endDate!.day);
      if (target.isAfter(effectiveEnd)) {
        return false;
      }
    }

    final interval = activity.recurrence.interval > 0 ? activity.recurrence.interval : 1;

    switch (activity.recurrence.type) {
      case RecurrenceType.never:
        return target == anchor;

      case RecurrenceType.daily:
        final diffDays = target.difference(effectiveStart).inDays;
        return diffDays >= 0 && (diffDays % interval == 0);

      case RecurrenceType.weekly:
        if (activity.recurrence.selectedWeekdays.isNotEmpty) {
          if (!activity.recurrence.selectedWeekdays.contains(target.weekday)) {
            return false;
          }
          final weekDiff = (target.difference(effectiveStart).inDays / 7).floor();
          return weekDiff >= 0 && (weekDiff % interval == 0);
        } else {
          if (target.weekday != effectiveStart.weekday) return false;
          final weekDiff = (target.difference(effectiveStart).inDays / 7).floor();
          return weekDiff >= 0 && (weekDiff % interval == 0);
        }

      case RecurrenceType.monthly:
        if (target.day != effectiveStart.day) return false;
        final monthDiff = (target.year - effectiveStart.year) * 12 +
            (target.month - effectiveStart.month);
        return monthDiff >= 0 && (monthDiff % interval == 0);

      case RecurrenceType.custom:
        if (activity.recurrence.selectedWeekdays.isNotEmpty) {
          if (!activity.recurrence.selectedWeekdays.contains(target.weekday)) {
            return false;
          }
          final weekDiff = (target.difference(effectiveStart).inDays / 7).floor();
          return weekDiff >= 0 && (weekDiff % interval == 0);
        }
        final diffDays = target.difference(effectiveStart).inDays;
        return diffDays >= 0 && (diffDays % interval == 0);
    }
  }

  /// Builds the concrete occurrence instance for a specific day,
  /// incorporating any single-occurrence edit/status overrides.
  static ActivityModel getOccurrenceForDate(ActivityModel activity, DateTime targetDate) {
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final isoDate = DateTimeUtils.toIsoDateString(target);

    // Calculate occurrence start and end time on the target day explicitly
    // preserving template hour and minute to prevent DST and timezone drift.
    final occStartTime = DateTime(
      target.year,
      target.month,
      target.day,
      activity.startTime.hour,
      activity.startTime.minute,
    );

    DateTime? occEndTime;
    if (activity.endTime != null) {
      final dayOffset = DateTime(
        activity.endTime!.year,
        activity.endTime!.month,
        activity.endTime!.day,
      ).difference(DateTime(
        activity.startTime.year,
        activity.startTime.month,
        activity.startTime.day,
      )).inDays;

      occEndTime = DateTime(
        target.year,
        target.month,
        target.day + dayOffset,
        activity.endTime!.hour,
        activity.endTime!.minute,
      );
    }

    var occurrence = activity.copyWith(
      occurrenceDate: target,
      recurrenceParentId: activity.id,
      date: target,
      startTime: occStartTime,
      endTime: occEndTime,
    );

    // Apply single-occurrence overrides if present
    final overrideMap = activity.recurrence.occurrenceOverrides[isoDate];
    if (overrideMap != null) {
      occurrence = ActivityModel.fromJson({
        ...occurrence.toJson(),
        ...overrideMap,
        'occurrenceDate': isoDate,
        'recurrenceParentId': activity.id,
      });
    }

    return occurrence;
  }

  /// Evaluates all activities over a bounded window [rangeStart, rangeEnd].
  /// Guaranteed safe execution capped to [maxDaysWindow].
  static List<ActivityModel> expandForRange(
    List<ActivityModel> activities,
    DateTime rangeStart,
    DateTime rangeEnd, {
    int maxDaysWindow = 90,
  }) {
    final results = <ActivityModel>[];
    final start = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final end = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);

    final totalDays = end.difference(start).inDays.abs() + 1;
    final cappedDays = totalDays > maxDaysWindow ? maxDaysWindow : totalDays;

    for (int i = 0; i < cappedDays; i++) {
      // Use calendar date increment instead of raw Duration addition to avoid DST clock shift
      final currentDay = DateTime(start.year, start.month, start.day + i);
      for (final act in activities) {
        if (occursOnDate(act, currentDay)) {
          results.add(getOccurrenceForDate(act, currentDay));
        }
      }
    }

    results.sort((a, b) => a.startTime.compareTo(b.startTime));
    return results;
  }

  /// Generates all occurrences of a [template] activity over a bounded window [rangeStart, rangeEnd].
  static List<ActivityModel> generateOccurrences({
    required ActivityModel template,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    int maxDaysWindow = 90,
  }) {
    if (!template.recurrence.isRecurring) {
      return [template];
    }

    final occurrences = expandForRange([template], rangeStart, rangeEnd, maxDaysWindow: maxDaysWindow);
    if (template.recurrence.maxOccurrences != null && template.recurrence.maxOccurrences! > 0) {
      return occurrences.take(template.recurrence.maxOccurrences!).toList();
    }
    return occurrences;
  }
}

