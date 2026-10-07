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
import 'package:activity_reminder_tracker/screens/calendar/calendar_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Calendar Screen & Views Widget Tests', () {
    testWidgets('1. Switches between Day, Week, and Month views seamlessly', (tester) async {
      final authService = AuthService(prefs);
      final notificationService = NotificationService(prefs, enableTimer: false);
      final activityService = ActivityService(prefs);

      final authCtrl = AuthController(authService);
      final activityCtrl = ActivityController(activityService, notificationService);
      final themeCtrl = ThemeController(prefs);

      await authCtrl.register(
        name: 'Alex Johnson',
        username: 'alex_j',
        email: 'alex@college.edu',
        password: 'Password123',
      );

      final today = DateTime.now();
      await activityCtrl.createActivity(
        userId: 'demo-id',
        title: 'Microprocessors Lab',
        category: ActivityCategory.lab,
        date: today,
        startTime: today.add(const Duration(hours: 10)),
        priority: ActivityPriority.high,
        location: 'Lab 4',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authCtrl),
            ChangeNotifierProvider.value(value: activityCtrl),
            ChangeNotifierProvider.value(value: themeCtrl),
          ],
          child: const MaterialApp(
            home: CalendarScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Day view controls
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      expect(find.text('Calendar & Routine'), findsOneWidget);

      // Tap Week View
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Monday'), findsOneWidget);

      // Tap Month View
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
    });
  });
}
