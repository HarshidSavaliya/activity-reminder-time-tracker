import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:activity_reminder_tracker/core/services/activity_service.dart';
import 'package:activity_reminder_tracker/core/services/auth_service.dart';
import 'package:activity_reminder_tracker/core/services/notification_service.dart';
import 'package:activity_reminder_tracker/models/enums/activity_category.dart';
import 'package:activity_reminder_tracker/models/enums/activity_priority.dart';
import 'package:activity_reminder_tracker/providers/activity_provider.dart';
import 'package:activity_reminder_tracker/providers/auth_provider.dart';
import 'package:activity_reminder_tracker/providers/theme_provider.dart';
import 'package:activity_reminder_tracker/screens/dashboard/dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Master-Level QA & Integration Suite', () {
    testWidgets('1. Master Home Screen UX & Meaningful Empty State', (tester) async {
      final authService = AuthService(prefs);
      final notificationService = NotificationService(prefs, enableTimer: false);
      final activityService = ActivityService(prefs);

      final authCtrl = AuthController(authService);
      final activityCtrl = ActivityController(activityService, notificationService);
      final themeCtrl = ThemeController(prefs);

      await authCtrl.register(
        name: 'Jordan Belfort',
        username: 'jbelfort',
        email: 'jordan@college.edu',
        password: 'Password123',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authCtrl),
            ChangeNotifierProvider.value(value: activityCtrl),
            ChangeNotifierProvider.value(value: themeCtrl),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Meaningful empty state when routine has 0 items
      expect(find.text('No activities today 🎉'), findsOneWidget);
      expect(
        find.text('Your schedule is clear. Relax, review your study notes, or schedule an activity.'),
        findsOneWidget,
      );
      expect(find.text('Add Activity'), findsWidgets);

      // Verify Quick Action shortcuts
      expect(find.text('Import PDF'), findsOneWidget);
    });

    testWidgets('2. Home Screen Tab Filter Switching', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final authService = AuthService(prefs);
      final notificationService = NotificationService(prefs, enableTimer: false);
      final activityService = ActivityService(prefs);

      final authCtrl = AuthController(authService);
      final activityCtrl = ActivityController(activityService, notificationService);
      final themeCtrl = ThemeController(prefs);

      await authCtrl.register(
        name: 'Ada Lovelace',
        username: 'alovelace',
        email: 'ada@college.edu',
        password: 'Password123',
      );

      final today = DateTime.now();
      await activityCtrl.createActivity(
        userId: 'user_ada',
        title: 'Microprocessor Architecture',
        category: ActivityCategory.lecture,
        date: today,
        startTime: today,
        priority: ActivityPriority.high,
        location: 'Room 101',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authCtrl),
            ChangeNotifierProvider.value(value: activityCtrl),
            ChangeNotifierProvider.value(value: themeCtrl),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify tab chips
      expect(find.text('All (1)'), findsOneWidget);
      expect(find.text('High Priority (1)'), findsOneWidget);
      expect(find.text('Pending (1)'), findsOneWidget);
      expect(find.text('Done (0)'), findsOneWidget);

      // Tap High Priority tab
      await tester.tap(find.text('High Priority (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Microprocessor Architecture'), findsWidgets);
    });

    test('3. Activity Notification Cleanup on Deletion', () async {
      final activityService = ActivityService(prefs);
      const userId = 'user_test';

      final initialActivities = await activityService.getActivities(userId);
      final initialCount = initialActivities.length;

      final activity = await activityService.createActivity(
        userId: userId,
        title: 'Algorithms Exam',
        category: ActivityCategory.exam,
        date: DateTime.now().add(const Duration(days: 1)),
        startTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
        priority: ActivityPriority.high,
      );

      expect(activity.id.isNotEmpty, isTrue);

      final afterCreate = await activityService.getActivities(userId);
      expect(afterCreate.length, equals(initialCount + 1));

      // Deleting activity cancels notifications and removes data
      await activityService.deleteActivity(userId, activity.id);
      final afterDelete = await activityService.getActivities(userId);
      expect(afterDelete.length, equals(initialCount));
    });
  });
}
