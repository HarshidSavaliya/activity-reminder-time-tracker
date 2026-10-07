import '../../models/activity_model.dart';
import '../../models/enums/activity_status.dart';
import 'recurrence_engine.dart';

/// Detailed result of a conflict evaluation.
class ConflictCheckResult {
  final bool hasConflict;
  final ActivityModel? conflictingActivity;
  final List<ActivityModel> allConflicts;
  final String? reason;

  const ConflictCheckResult({
    required this.hasConflict,
    this.conflictingActivity,
    this.allConflicts = const [],
    this.reason,
  });

  static const ConflictCheckResult none = ConflictCheckResult(hasConflict: false);
}

/// ConflictResolutionEngine provides high-precision interval collision detection,
/// handling boundary conditions (back-to-back tasks), zero-duration tasks,
/// recurring virtual occurrences, and multi-conflict reporting.
class ConflictResolutionEngine {
  ConflictResolutionEngine._();

  /// Default duration applied when an activity has no explicit end time.
  static const Duration defaultDuration = Duration(minutes: 45);

  /// Evaluates whether two time intervals overlap.
  ///
  /// Mathematical rule:
  /// Collision <=> StartA < EndB AND EndA > StartB
  ///
  /// Boundary cases:
  /// - Event A ends at 10:00, Event B starts at 10:00:
  ///   EndA (10:00) is NOT after StartB (10:00). Returns FALSE (no collision).
  ///
  /// Zero-duration handling:
  /// - If StartA == EndA (instantaneous pin), it collides with [StartB, EndB]
  ///   if StartB < StartA < EndB.
  /// - If both are instantaneous at the exact same timestamp, returns TRUE.
  static bool areIntervalsOverlapping({
    required DateTime startA,
    required DateTime endA,
    required DateTime startB,
    required DateTime endB,
  }) {
    // Normalize in case end is mistakenly before start
    final normalizedEndA = endA.isBefore(startA) ? startA : endA;
    final normalizedEndB = endB.isBefore(startB) ? startB : endB;

    final isZeroA = startA.isAtSameMomentAs(normalizedEndA);
    final isZeroB = startB.isAtSameMomentAs(normalizedEndB);

    // Both instantaneous
    if (isZeroA && isZeroB) {
      return startA.isAtSameMomentAs(startB);
    }

    // A is instantaneous
    if (isZeroA) {
      return startA.isAfter(startB) && startA.isBefore(normalizedEndB);
    }

    // B is instantaneous
    if (isZeroB) {
      return startB.isAfter(startA) && startB.isBefore(normalizedEndA);
    }

    // Standard interval overlap: StartA < EndB && EndA > StartB
    return startA.isBefore(normalizedEndB) && normalizedEndA.isAfter(startB);
  }

  /// Finds all conflicting activities on [date] for the given time window.
  static List<ActivityModel> findAllConflicts({
    required List<ActivityModel> existingActivities,
    required DateTime date,
    required DateTime startTime,
    required DateTime? endTime,
    String? excludeActivityId,
  }) {
    final targetDay = DateTime(date.year, date.month, date.day);
    final dayOccurrences =
        RecurrenceEngine.expandForRange(existingActivities, targetDay, targetDay);

    final candidateStart = DateTime(
      targetDay.year,
      targetDay.month,
      targetDay.day,
      startTime.hour,
      startTime.minute,
    );

    final candidateEnd = endTime != null
        ? DateTime(
            targetDay.year,
            targetDay.month,
            targetDay.day,
            endTime.hour,
            endTime.minute,
          )
        : candidateStart.add(defaultDuration);

    final conflicts = <ActivityModel>[];

    for (final existing in dayOccurrences) {
      // Ignore self (including recurrence series parent)
      if (excludeActivityId != null &&
          (existing.id == excludeActivityId ||
              existing.recurrenceParentId == excludeActivityId)) {
        continue;
      }

      // Ignore cancelled activities
      if (existing.status == ActivityStatus.cancelled) {
        continue;
      }

      final existingStart = existing.startTime;
      final existingEnd = existing.endTime ?? existingStart.add(defaultDuration);

      if (areIntervalsOverlapping(
        startA: candidateStart,
        endA: candidateEnd,
        startB: existingStart,
        endB: existingEnd,
      )) {
        conflicts.add(existing);
      }
    }

    return conflicts;
  }

  /// Returns the first conflicting activity, or null if no conflict exists.
  static ActivityModel? findFirstConflict({
    required List<ActivityModel> existingActivities,
    required DateTime date,
    required DateTime startTime,
    required DateTime? endTime,
    String? excludeActivityId,
  }) {
    final conflicts = findAllConflicts(
      existingActivities: existingActivities,
      date: date,
      startTime: startTime,
      endTime: endTime,
      excludeActivityId: excludeActivityId,
    );
    return conflicts.isEmpty ? null : conflicts.first;
  }

  /// Performs a comprehensive conflict check and returns a structured [ConflictCheckResult].
  static ConflictCheckResult checkConflict({
    required List<ActivityModel> existingActivities,
    required DateTime date,
    required DateTime startTime,
    required DateTime? endTime,
    String? excludeActivityId,
  }) {
    final conflicts = findAllConflicts(
      existingActivities: existingActivities,
      date: date,
      startTime: startTime,
      endTime: endTime,
      excludeActivityId: excludeActivityId,
    );

    if (conflicts.isEmpty) {
      return ConflictCheckResult.none;
    }

    final primary = conflicts.first;
    final primaryEnd = primary.endTime ?? primary.startTime.add(defaultDuration);
    final reason = 'Overlaps with "${primary.title}" '
        '(${primary.startTime.hour.toString().padLeft(2, '0')}:${primary.startTime.minute.toString().padLeft(2, '0')} - '
        '${primaryEnd.hour.toString().padLeft(2, '0')}:${primaryEnd.minute.toString().padLeft(2, '0')})';
    return ConflictCheckResult(
      hasConflict: true,
      conflictingActivity: primary,
      allConflicts: conflicts,
      reason: reason,
    );
  }

  /// Performs a direct collision check between two activities on their scheduled dates.
  static bool hasCollision(ActivityModel a, ActivityModel b) {
    if (a.id == b.id) return false;
    if (a.status == ActivityStatus.cancelled || b.status == ActivityStatus.cancelled) return false;

    final targetDate = DateTime(a.date.year, a.date.month, a.date.day);
    if (!RecurrenceEngine.occursOnDate(a, targetDate) || !RecurrenceEngine.occursOnDate(b, targetDate)) {
      // Check if both occur on any matching date
      final aDate = DateTime(a.date.year, a.date.month, a.date.day);
      final bDate = DateTime(b.date.year, b.date.month, b.date.day);
      if (aDate != bDate && !a.recurrence.isRecurring && !b.recurrence.isRecurring) {
        return false;
      }
    }

    final startA = a.startTime;
    final endA = a.endTime ?? startA.add(defaultDuration);
    final startB = b.startTime;
    final endB = b.endTime ?? startB.add(defaultDuration);

    final normStartA = DateTime(2000, 1, 1, startA.hour, startA.minute);
    final normEndA = DateTime(2000, 1, 1, endA.hour, endA.minute);
    final normStartB = DateTime(2000, 1, 1, startB.hour, startB.minute);
    final normEndB = DateTime(2000, 1, 1, endB.hour, endB.minute);

    return areIntervalsOverlapping(
      startA: normStartA,
      endA: normEndA,
      startB: normStartB,
      endB: normEndB,
    );
  }

  /// Convenience wrapper to find all conflicts for a [target] activity.
  static List<ActivityModel> findConflicts({
    required ActivityModel target,
    required List<ActivityModel> existingActivities,
  }) {
    return findAllConflicts(
      existingActivities: existingActivities,
      date: target.date,
      startTime: target.startTime,
      endTime: target.endTime,
      excludeActivityId: target.id,
    );
  }
}

