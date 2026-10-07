import 'package:flutter_test/flutter_test.dart';
import 'package:activity_reminder_tracker/core/utils/recurrence_engine.dart';
import 'package:activity_reminder_tracker/models/activity_model.dart';
import 'package:activity_reminder_tracker/models/enums/activity_category.dart';
import 'package:activity_reminder_tracker/models/enums/activity_priority.dart';
import 'package:activity_reminder_tracker/models/recurrence_rule.dart';

void main() {
  group('RecurrenceEngine Tests', () {
    final template = ActivityModel(
      id: 'template-1',
      userId: 'user-1',
      title: 'Operating Systems Lecture',
      date: DateTime(2026, 10, 5), // Monday
      startTime: DateTime(2026, 10, 5, 9, 30),
      endTime: DateTime(2026, 10, 5, 11, 0),
      category: ActivityCategory.lecture,
      priority: ActivityPriority.high,
      recurrence: const RecurrenceRule(
        type: RecurrenceType.weekly,
        selectedWeekdays: [DateTime.monday],
      ),
    );

    test('Preserves explicit template hour and minute across all occurrences (No clock shift)', () {
      final rangeStart = DateTime(2026, 10, 5);
      final rangeEnd = DateTime(2026, 11, 30);

      final occurrences = RecurrenceEngine.generateOccurrences(
        template: template,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(occurrences, isNotEmpty);
      for (final occ in occurrences) {
        expect(occ.startTime.hour, equals(9));
        expect(occ.startTime.minute, equals(30));
        expect(occ.endTime!.hour, equals(11));
        expect(occ.endTime!.minute, equals(0));
        expect(occ.recurrenceParentId, equals('template-1'));
      }
    });

    test('Generates daily occurrences correctly within range', () {
      final dailyTemplate = template.copyWith(
        recurrence: const RecurrenceRule(type: RecurrenceType.daily),
      );

      final occurrences = RecurrenceEngine.generateOccurrences(
        template: dailyTemplate,
        rangeStart: DateTime(2026, 10, 5),
        rangeEnd: DateTime(2026, 10, 9),
      );

      // Oct 5, 6, 7, 8, 9 = 5 days
      expect(occurrences.length, equals(5));
      for (int i = 0; i < 5; i++) {
        expect(occurrences[i].date.day, equals(5 + i));
        expect(occurrences[i].startTime.hour, equals(9));
        expect(occurrences[i].startTime.minute, equals(30));
      }
    });

    test('Respects RecurrenceRule.endDate limit', () {
      final limitedTemplate = template.copyWith(
        recurrence: RecurrenceRule(
          type: RecurrenceType.weekly,
          selectedWeekdays: const [DateTime.monday],
          endDate: DateTime(2026, 10, 19), // Only allows up to Oct 19
        ),
      );

      final occurrences = RecurrenceEngine.generateOccurrences(
        template: limitedTemplate,
        rangeStart: DateTime(2026, 10, 5),
        rangeEnd: DateTime(2026, 12, 31),
      );

      // Mondays: Oct 5, Oct 12, Oct 19
      expect(occurrences.length, equals(3));
      expect(occurrences.last.date.day, equals(19));
    });

    test('Respects maxOccurrences limit', () {
      final limitedTemplate = template.copyWith(
        recurrence: const RecurrenceRule(
          type: RecurrenceType.weekly,
          selectedWeekdays: [DateTime.monday],
          maxOccurrences: 2,
        ),
      );

      final occurrences = RecurrenceEngine.generateOccurrences(
        template: limitedTemplate,
        rangeStart: DateTime(2026, 10, 5),
        rangeEnd: DateTime(2026, 12, 31),
      );

      expect(occurrences.length, equals(2));
    });

    test('Returns single instance when recurrence type is none', () {
      final nonRecurring = template.copyWith(
        recurrence: const RecurrenceRule(type: RecurrenceType.none),
      );

      final occurrences = RecurrenceEngine.generateOccurrences(
        template: nonRecurring,
        rangeStart: DateTime(2026, 10, 1),
        rangeEnd: DateTime(2026, 10, 31),
      );

      expect(occurrences.length, equals(1));
      expect(occurrences.first.id, equals(nonRecurring.id));
    });
  });
}
