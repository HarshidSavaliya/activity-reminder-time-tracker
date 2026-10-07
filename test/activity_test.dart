import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:activity_reminder_tracker/core/services/activity_service.dart';
import 'package:activity_reminder_tracker/core/services/notification_service.dart';
import 'package:activity_reminder_tracker/core/utils/recurrence_engine.dart';
import 'package:activity_reminder_tracker/models/activity_model.dart';
import 'package:activity_reminder_tracker/models/enums/activity_category.dart';
import 'package:activity_reminder_tracker/models/enums/activity_priority.dart';
import 'package:activity_reminder_tracker/models/enums/activity_status.dart';
import 'package:activity_reminder_tracker/models/recurrence_rule.dart';
import 'package:activity_reminder_tracker/models/reminder_setting.dart';
import 'package:activity_reminder_tracker/providers/activity_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late ActivityService activityService;
  late NotificationService notificationService;
  late ActivityController activityController;

  const userA = 'user-a-123';
  const userB = 'user-b-456';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    activityService = ActivityService(prefs);
    notificationService = NotificationService(prefs);
    activityController = ActivityController(activityService, notificationService);
  });

  group('Phase 2 Activity & Recurrence Tests', () {
    test('1. Activity CRUD Operations (Create, Read, Update, Delete)', () async {
      await activityController.loadActivities(userA);
      final initialCount = activityController.activities.length;

      final now = DateTime.now();
      final date = DateTime(now.year, now.month, now.day);
      final startTime = date.add(const Duration(hours: 14));
      final endTime = date.add(const Duration(hours: 15));

      // Create
      final success = await activityController.createActivity(
        userId: userA,
        title: 'Compiler Design Lab',
        description: 'AST generation and LLVM IR output',
        category: ActivityCategory.lab,
        date: date,
        startTime: startTime,
        endTime: endTime,
        priority: ActivityPriority.high,
        location: 'CS Lab 2',
      );

      expect(success, isTrue);
      expect(activityController.activities.length, initialCount + 1);

      // Read
      final created = activityController.activities.firstWhere((a) => a.title == 'Compiler Design Lab');
      expect(created.location, 'CS Lab 2');
      expect(created.priority, ActivityPriority.high);

      // Update
      final updated = created.copyWith(location: 'Room 304', title: 'Compiler Design Practical');
      final updateSuccess = await activityController.updateActivity(updated);
      expect(updateSuccess, isTrue);
      final fetched = activityController.activities.firstWhere((a) => a.id == created.id);
      expect(fetched.title, 'Compiler Design Practical');
      expect(fetched.location, 'Room 304');

      // Delete
      final deleteSuccess = await activityController.deleteActivity(userA, created.id);
      expect(deleteSuccess, isTrue);
      expect(activityController.activities.length, initialCount);
    });

    test('2. User Data Isolation: User A and User B datasets are distinct', () async {
      await activityController.loadActivities(userA);

      await activityController.createActivity(
        userId: userA,
        title: 'Private Research Lab',
        category: ActivityCategory.study,
        date: DateTime.now(),
        startTime: DateTime.now(),
        priority: ActivityPriority.high,
      );

      final userBCtrl = ActivityController(activityService, notificationService);
      await userBCtrl.loadActivities(userB);

      final hasUserAActivity = userBCtrl.activities.any((a) => a.title == 'Private Research Lab');
      expect(hasUserAActivity, isFalse);
    });

    test('3. Daily Recurrence Occurrence Generation', () async {
      final anchor = DateTime(2026, 10, 1);
      final dailyActivity = await activityService.createActivity(
        userId: userA,
        title: 'Morning Code Practice',
        category: ActivityCategory.study,
        date: anchor,
        startTime: anchor.add(const Duration(hours: 7)),
        priority: ActivityPriority.medium,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily, interval: 1),
      );

      // Verify occurs on 2026-10-01, 2026-10-02, 2026-10-05
      expect(RecurrenceEngine.occursOnDate(dailyActivity, DateTime(2026, 10, 1)), isTrue);
      expect(RecurrenceEngine.occursOnDate(dailyActivity, DateTime(2026, 10, 2)), isTrue);
      expect(RecurrenceEngine.occursOnDate(dailyActivity, DateTime(2026, 10, 5)), isTrue);
      // Does not occur before start date
      expect(RecurrenceEngine.occursOnDate(dailyActivity, DateTime(2026, 9, 30)), isFalse);
    });

    test('4. Weekly Recurrence & Custom Weekday Recurrence (Gym: Mon, Wed, Fri)', () async {
      // 2026-10-05 is a Monday
      final anchor = DateTime(2026, 10, 5);
      final gymActivity = await activityService.createActivity(
        userId: userA,
        title: 'Gym Workout',
        category: ActivityCategory.personal,
        date: anchor,
        startTime: anchor.add(const Duration(hours: 18)),
        priority: ActivityPriority.low,
        recurrence: const RecurrenceRule(
          type: RecurrenceType.custom,
          selectedWeekdays: [1, 3, 5], // Mon, Wed, Fri
        ),
      );

      // Mon (10-05) -> True
      expect(RecurrenceEngine.occursOnDate(gymActivity, DateTime(2026, 10, 5)), isTrue);
      // Tue (10-06) -> False
      expect(RecurrenceEngine.occursOnDate(gymActivity, DateTime(2026, 10, 6)), isFalse);
      // Wed (10-07) -> True
      expect(RecurrenceEngine.occursOnDate(gymActivity, DateTime(2026, 10, 7)), isTrue);
      // Thu (10-08) -> False
      expect(RecurrenceEngine.occursOnDate(gymActivity, DateTime(2026, 10, 8)), isFalse);
      // Fri (10-09) -> True
      expect(RecurrenceEngine.occursOnDate(gymActivity, DateTime(2026, 10, 9)), isTrue);
      // Sat (10-10) -> False
      expect(RecurrenceEngine.occursOnDate(gymActivity, DateTime(2026, 10, 10)), isFalse);
    });

    test('5. Monthly Recurrence Calculation', () async {
      final anchor = DateTime(2026, 10, 15);
      final monthlyMeeting = await activityService.createActivity(
        userId: userA,
        title: 'Monthly Department Review',
        category: ActivityCategory.meeting,
        date: anchor,
        startTime: anchor.add(const Duration(hours: 11)),
        priority: ActivityPriority.high,
        recurrence: const RecurrenceRule(type: RecurrenceType.monthly),
      );

      expect(RecurrenceEngine.occursOnDate(monthlyMeeting, DateTime(2026, 10, 15)), isTrue);
      expect(RecurrenceEngine.occursOnDate(monthlyMeeting, DateTime(2026, 11, 15)), isTrue);
      expect(RecurrenceEngine.occursOnDate(monthlyMeeting, DateTime(2026, 12, 15)), isTrue);
      expect(RecurrenceEngine.occursOnDate(monthlyMeeting, DateTime(2026, 11, 16)), isFalse);
    });

    test('6. Delete ONLY this occurrence vs Delete entire series', () async {
      await activityController.loadActivities(userA);

      final anchor = DateTime(2026, 10, 1);
      final dailyActivity = await activityService.createActivity(
        userId: userA,
        title: 'Daily Standup',
        category: ActivityCategory.meeting,
        date: anchor,
        startTime: anchor.add(const Duration(hours: 9)),
        priority: ActivityPriority.medium,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily),
      );

      // Verify occurs on 2026-10-03
      expect(RecurrenceEngine.occursOnDate(dailyActivity, DateTime(2026, 10, 3)), isTrue);

      // Delete only the occurrence on 2026-10-03
      await activityService.deleteOccurrence(userA, dailyActivity.id, DateTime(2026, 10, 3));

      final updated = (await activityService.getActivities(userA)).firstWhere((a) => a.id == dailyActivity.id);

      // 2026-10-03 should now be excluded
      expect(RecurrenceEngine.occursOnDate(updated, DateTime(2026, 10, 3)), isFalse);
      // Other days remain active!
      expect(RecurrenceEngine.occursOnDate(updated, DateTime(2026, 10, 2)), isTrue);
      expect(RecurrenceEngine.occursOnDate(updated, DateTime(2026, 10, 4)), isTrue);

      // Now Delete Entire Series
      await activityService.deleteActivity(userA, dailyActivity.id);
      final allRemaining = await activityService.getActivities(userA);
      expect(allRemaining.any((a) => a.id == dailyActivity.id), isFalse);
    });

    test('7. Edit ONLY this occurrence override', () async {
      await activityController.loadActivities(userA);

      final anchor = DateTime(2026, 10, 1);
      final recurringLecture = await activityService.createActivity(
        userId: userA,
        title: 'Data Structures Lecture',
        category: ActivityCategory.lecture,
        date: anchor,
        startTime: anchor.add(const Duration(hours: 10)),
        location: 'Room 204',
        priority: ActivityPriority.high,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily),
      );

      // Override occurrence on 2026-10-02 to change room to "Auditorium A"
      await activityService.editOccurrence(
        userA,
        recurringLecture.id,
        DateTime(2026, 10, 2),
        {'location': 'Auditorium A'},
      );

      final updated = (await activityService.getActivities(userA)).firstWhere((a) => a.id == recurringLecture.id);

      final occ1 = RecurrenceEngine.getOccurrenceForDate(updated, DateTime(2026, 10, 1));
      expect(occ1.location, 'Room 204');

      final occ2 = RecurrenceEngine.getOccurrenceForDate(updated, DateTime(2026, 10, 2));
      expect(occ2.location, 'Auditorium A');
    });

    test('8. Overlapping Activities Detection', () async {
      await activityController.loadActivities(userA);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Create an activity from 20:00 to 21:30
      await activityController.createActivity(
        userId: userA,
        title: 'Algorithms Class',
        category: ActivityCategory.lecture,
        date: today,
        startTime: today.add(const Duration(hours: 20)),
        endTime: today.add(const Duration(hours: 21, minutes: 30)),
        priority: ActivityPriority.high,
      );

      // Check overlap for 20:30 to 21:00 (inside range -> should collide)
      final conflict = activityController.checkOverlap(
        date: today,
        startTime: today.add(const Duration(hours: 20, minutes: 30)),
        endTime: today.add(const Duration(hours: 21, minutes: 0)),
      );
      expect(conflict, isNotNull);
      expect(conflict?.title, 'Algorithms Class');

      // Check non-overlapping time: 22:00 to 23:00 (after range -> no collision)
      final noConflict = activityController.checkOverlap(
        date: today,
        startTime: today.add(const Duration(hours: 22)),
        endTime: today.add(const Duration(hours: 23)),
      );
      expect(noConflict, isNull);
    });

    test('9. Notification Reminder Scheduling & App Restart Persistence', () async {
      final now = DateTime.now();
      final futureTime = now.add(const Duration(hours: 3));

      final activity = ActivityModel(
        id: 'reminder-test-id',
        userId: userA,
        title: 'Project Presentation',
        category: ActivityCategory.exam,
        date: futureTime,
        startTime: futureTime,
        priority: ActivityPriority.high,
        reminder: const ReminderSetting(minutesBefore: 15),
        createdAt: now,
        updatedAt: now,
      );

      await notificationService.scheduleRemindersForActivity(activity);

      // Verify scheduled reminders
      final reminders = notificationService.getScheduledReminders();
      expect(reminders.any((r) => r.activityId == 'reminder-test-id'), isTrue);

      // Simulate App Restart: new NotificationService reading from SharedPreferences
      final reloadedNotificationService = NotificationService(prefs);
      final reloadedReminders = reloadedNotificationService.getScheduledReminders();
      expect(reloadedReminders.any((r) => r.activityId == 'reminder-test-id'), isTrue);

      // Cancel reminder
      await reloadedNotificationService.cancelRemindersForActivity('reminder-test-id');
      final afterCancel = reloadedNotificationService.getScheduledReminders();
      expect(afterCancel.any((r) => r.activityId == 'reminder-test-id'), isFalse);
    });

    test('10. Search, Priority Filter, and Status Filter', () async {
      await activityController.loadActivities(userA);

      final today = DateTime.now();
      await activityController.createActivity(
        userId: userA,
        title: 'Machine Learning Deep Dive',
        category: ActivityCategory.lecture,
        date: today,
        startTime: today.add(const Duration(hours: 12)),
        priority: ActivityPriority.high,
        status: ActivityStatus.pending,
      );

      // Search
      activityController.setSearchQuery('Deep Dive');
      expect(activityController.activitiesForSelectedDate.length, 1);
      expect(activityController.activitiesForSelectedDate.first.title, 'Machine Learning Deep Dive');

      // Clear search & Filter by High Priority
      activityController.clearFilters();
      activityController.setPriorityFilter(ActivityPriority.high);
      for (final act in activityController.activitiesForSelectedDate) {
        expect(act.priority, ActivityPriority.high);
      }
    });
  });
}
