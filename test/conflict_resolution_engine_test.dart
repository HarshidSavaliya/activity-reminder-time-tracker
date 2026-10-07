import 'package:flutter_test/flutter_test.dart';
import 'package:activity_reminder_tracker/core/utils/conflict_resolution_engine.dart';
import 'package:activity_reminder_tracker/models/activity_model.dart';
import 'package:activity_reminder_tracker/models/enums/activity_category.dart';
import 'package:activity_reminder_tracker/models/enums/activity_priority.dart';
import 'package:activity_reminder_tracker/models/recurrence_rule.dart';

void main() {
  group('ConflictResolutionEngine Tests', () {
    final baseDate = DateTime(2026, 10, 5); // Monday

    ActivityModel createSample({
      required String id,
      required DateTime date,
      required DateTime start,
      required DateTime end,
      RecurrenceRule? recurrence,
    }) {
      return ActivityModel(
        id: id,
        userId: 'u1',
        title: 'Activity $id',
        date: date,
        startTime: start,
        endTime: end,
        category: ActivityCategory.lecture,
        priority: ActivityPriority.medium,
        recurrence: recurrence ?? const RecurrenceRule(type: RecurrenceType.none),
      );
    }

    test('Back-to-back classes do NOT collide (A: 9-10, B: 10-11)', () {
      final a = createSample(
        id: '1',
        date: baseDate,
        start: DateTime(2026, 10, 5, 9, 0),
        end: DateTime(2026, 10, 5, 10, 0),
      );
      final b = createSample(
        id: '2',
        date: baseDate,
        start: DateTime(2026, 10, 5, 10, 0),
        end: DateTime(2026, 10, 5, 11, 0),
      );

      final conflicts = ConflictResolutionEngine.findConflicts(
        target: b,
        existingActivities: [a],
      );

      expect(conflicts, isEmpty);
      expect(ConflictResolutionEngine.hasCollision(a, b), isFalse);
    });

    test('Strict collision when times overlap (A: 9:00-10:15, B: 10:00-11:00)', () {
      final a = createSample(
        id: '1',
        date: baseDate,
        start: DateTime(2026, 10, 5, 9, 0),
        end: DateTime(2026, 10, 5, 10, 15),
      );
      final b = createSample(
        id: '2',
        date: baseDate,
        start: DateTime(2026, 10, 5, 10, 0),
        end: DateTime(2026, 10, 5, 11, 0),
      );

      final conflicts = ConflictResolutionEngine.findConflicts(
        target: b,
        existingActivities: [a],
      );

      expect(conflicts.length, equals(1));
      expect(conflicts.first.id, equals('1'));
      expect(ConflictResolutionEngine.hasCollision(a, b), isTrue);
    });

    test('No collision when on different days', () {
      final a = createSample(
        id: '1',
        date: baseDate,
        start: DateTime(2026, 10, 5, 10, 0),
        end: DateTime(2026, 10, 5, 11, 0),
      );
      final b = createSample(
        id: '2',
        date: baseDate.add(const Duration(days: 1)), // Tuesday
        start: DateTime(2026, 10, 6, 10, 0),
        end: DateTime(2026, 10, 6, 11, 0),
      );

      final conflicts = ConflictResolutionEngine.findConflicts(
        target: b,
        existingActivities: [a],
      );

      expect(conflicts, isEmpty);
    });

    test('Self comparison is ignored', () {
      final a = createSample(
        id: '1',
        date: baseDate,
        start: DateTime(2026, 10, 5, 10, 0),
        end: DateTime(2026, 10, 5, 11, 0),
      );

      final conflicts = ConflictResolutionEngine.findConflicts(
        target: a,
        existingActivities: [a],
      );

      expect(conflicts, isEmpty);
    });

    test('Weekly recurring activities collision detection on matching weekday', () {
      final a = createSample(
        id: '1',
        date: baseDate, // Monday Oct 5
        start: DateTime(2026, 10, 5, 10, 0),
        end: DateTime(2026, 10, 5, 11, 0),
        recurrence: const RecurrenceRule(
          type: RecurrenceType.weekly,
          selectedWeekdays: [DateTime.monday],
        ),
      );
      final b = createSample(
        id: '2',
        date: baseDate.add(const Duration(days: 7)), // Monday Oct 12
        start: DateTime(2026, 10, 12, 10, 30),
        end: DateTime(2026, 10, 12, 11, 30),
      );

      final conflicts = ConflictResolutionEngine.findConflicts(
        target: b,
        existingActivities: [a],
      );

      expect(conflicts.length, equals(1));
    });
  });
}
