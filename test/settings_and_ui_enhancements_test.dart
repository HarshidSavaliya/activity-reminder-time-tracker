import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:activity_reminder_tracker/core/services/activity_service.dart';
import 'package:activity_reminder_tracker/core/services/auth_service.dart';
import 'package:activity_reminder_tracker/models/activity_model.dart';
import 'package:activity_reminder_tracker/models/enums/activity_category.dart';
import 'package:activity_reminder_tracker/models/enums/activity_priority.dart';
import 'package:activity_reminder_tracker/models/enums/activity_status.dart';
import 'package:activity_reminder_tracker/providers/activity_provider.dart';
import 'package:activity_reminder_tracker/providers/auth_provider.dart';
import 'package:activity_reminder_tracker/providers/theme_provider.dart';
import 'package:activity_reminder_tracker/screens/dashboard/widgets/hero_activity_card.dart';
import 'package:activity_reminder_tracker/screens/main_navigation_shell.dart';
import 'package:activity_reminder_tracker/screens/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'app_hide_completed': true,
    });
    prefs = await SharedPreferences.getInstance();
  });

  group('User Request Enhancements Tests (i1 - i5)', () {
    test('i4 & i3: ActivityProvider hides completed activities and computes dynamic stats', () async {
      final activityService = ActivityService(prefs);
      final activityCtrl = ActivityProvider(activityService);

      final now = DateTime.now();
      await activityService.createActivity(
        userId: 'user-1',
        title: 'Algorithms Lecture',
        date: now,
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now,
        status: ActivityStatus.completed,
        priority: ActivityPriority.high,
        category: ActivityCategory.lecture,
      );

      await activityService.createActivity(
        userId: 'user-1',
        title: 'Operating Systems Lab',
        date: now,
        startTime: now.add(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 2)),
        status: ActivityStatus.pending,
        priority: ActivityPriority.medium,
        category: ActivityCategory.lab,
      );

      await activityCtrl.loadActivities('user-1');

      // Total count includes all activities
      final total = activityCtrl.todayTotalCount;
      final completed = activityCtrl.todayCompletedCount;
      final pending = activityCtrl.todayPendingCount;
      expect(total, equals(completed + pending));
      expect(completed, greaterThanOrEqualTo(1));

      // With hideCompleted = true, completed activities are excluded from todayActivities
      expect(activityCtrl.hideCompleted, isTrue);
      expect(activityCtrl.todayActivities.length, equals(pending));
      expect(activityCtrl.todayActivities.every((a) => !a.isCompleted), isTrue);

      // If user toggles hideCompleted = false, both completed and pending appear
      await activityCtrl.setHideCompleted(false);
      expect(activityCtrl.hideCompleted, isFalse);
      expect(activityCtrl.todayActivities.length, equals(total));

      // Dynamic stats calculation for week
      final stats = activityCtrl.getWeeklyStats(now);
      expect(stats.totalCount, greaterThanOrEqualTo(2));
      expect(stats.maxY, greaterThanOrEqualTo(5.0));
    });

    testWidgets('i2: HeroActivityCard renders without dummy user logos (A, J, +)', (tester) async {
      final now = DateTime.now();
      final sampleActivity = ActivityModel(
        id: 'hero-act',
        userId: 'user-1',
        title: 'Operating System',
        date: now,
        startTime: now,
        endTime: now.add(const Duration(minutes: 75)),
        status: ActivityStatus.pending,
        priority: ActivityPriority.medium,
        category: ActivityCategory.lecture,
        location: 'Office / Main Workspace',
        createdAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeroActivityCard(
              activity: sampleActivity,
              onTap: () {},
              onToggleComplete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title & badges are present
      expect(find.text('Operating System'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);

      // Dummy user logos ('A', 'J', '+') must NOT be present
      expect(find.text('A'), findsNothing);
      expect(find.text('J'), findsNothing);
      expect(find.text('+'), findsNothing);
    });

    testWidgets('i1: SettingsScreen displays preference controls and toggles hide completed', (tester) async {
      final authService = AuthService(prefs);
      final activityService = ActivityService(prefs);
      final authCtrl = AuthController(authService);
      final activityCtrl = ActivityController(activityService);

      await authCtrl.register(
        name: 'Jordan Miller',
        username: 'jordan_m',
        email: 'jordan@college.edu',
        password: 'Password123',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authCtrl),
            ChangeNotifierProvider.value(value: activityCtrl),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Hide Completed Activities'), findsOneWidget);
      expect(find.text('Adobe Acrobat Services & Embed API'), findsOneWidget);
      expect(find.text('Notification Settings'), findsOneWidget);
      expect(find.text('SQLite 3 Database Inspector'), findsOneWidget);

      // Verify toggle switch interaction
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(activityCtrl.hideCompleted, isFalse);
    });

    testWidgets('i5 & i1: MainNavigationShell has balanced 5-item floating bottom bar with Settings', (tester) async {
      final authService = AuthService(prefs);
      final activityService = ActivityService(prefs);
      final authCtrl = AuthController(authService);
      final activityCtrl = ActivityController(activityService);
      final themeCtrl = ThemeController(prefs);

      await authCtrl.register(
        name: 'Jordan Miller',
        username: 'jordan_m',
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
            home: MainNavigationShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigation tabs verification
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.byTooltip('Add New Activity'), findsOneWidget);

      // Tap settings tab to verify navigation
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Hide Completed Activities'), findsOneWidget);
    });
  });
}
