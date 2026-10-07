import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:activity_reminder_tracker/core/services/activity_service.dart';
import 'package:activity_reminder_tracker/core/services/auth_service.dart';
import 'package:activity_reminder_tracker/core/utils/validators.dart';
import 'package:activity_reminder_tracker/providers/activity_provider.dart';
import 'package:activity_reminder_tracker/providers/auth_provider.dart';
import 'package:activity_reminder_tracker/providers/theme_provider.dart';
import 'package:activity_reminder_tracker/screens/main_navigation_shell.dart';
import 'package:activity_reminder_tracker/widgets/empty_state_view.dart';
import 'package:activity_reminder_tracker/widgets/priority_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('UI / UX Widget Tests', () {
    testWidgets('1. PriorityBadge renders High, Medium, Low badges properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PriorityBadge(priority: PriorityLevel.high),
                PriorityBadge(priority: PriorityLevel.medium),
                PriorityBadge(priority: PriorityLevel.low),
              ],
            ),
          ),
        ),
      );

      expect(find.text('High'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
    });

    testWidgets('2. EmptyStateView renders title, message, and action button', (tester) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateView(
              icon: Icons.event_busy_rounded,
              title: 'No classes today',
              message: 'Take a break or review your notes',
              actionText: 'Add Activity',
              onAction: () {
                actionTriggered = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('No classes today'), findsOneWidget);
      expect(find.text('Take a break or review your notes'), findsOneWidget);
      expect(find.text('Add Activity'), findsOneWidget);

      await tester.tap(find.text('Add Activity'));
      expect(actionTriggered, isTrue);
    });

    testWidgets('3. ThemeController handles theme switching and persistence', (tester) async {
      final themeCtrl = ThemeController(prefs);

      expect(themeCtrl.themeMode, ThemeMode.system);

      await themeCtrl.setThemeMode(ThemeMode.dark);
      expect(themeCtrl.themeMode, ThemeMode.dark);
      expect(themeCtrl.isDarkMode, isTrue);

      await themeCtrl.setThemeMode(ThemeMode.light);
      expect(themeCtrl.themeMode, ThemeMode.light);
      expect(themeCtrl.isDarkMode, isFalse);
    });

    test('4. Form validators unit tests', () {
      // Email
      expect(Validators.validateEmail(''), isNotNull);
      expect(Validators.validateEmail('invalid-email'), isNotNull);
      expect(Validators.validateEmail('alex@college.edu'), isNull);

      // Password
      expect(Validators.validatePassword('short'), isNotNull);
      expect(Validators.validatePassword('allletters'), isNotNull);
      expect(Validators.validatePassword('Password123'), isNull);

      // Activity Title
      expect(Validators.validateActivityTitle(''), isNotNull);
      expect(Validators.validateActivityTitle('AB'), isNotNull);
      expect(Validators.validateActivityTitle('Data Structures'), isNull);
    });

    testWidgets('5. MainNavigationShell renders bottom navigation tabs', (tester) async {
      final authService = AuthService(prefs);
      final activityService = ActivityService(prefs);

      final authCtrl = AuthController(authService);
      final activityCtrl = ActivityController(activityService);
      final themeCtrl = ThemeController(prefs);

      // Register and login a user for the navigation shell
      await authCtrl.register(
        name: 'Alex Johnson',
        username: 'alex_j',
        email: 'alex@college.edu',
        password: 'Password123',
      );
      await activityCtrl.loadActivities('user-id');

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

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.byTooltip('Add New Activity'), findsOneWidget);

      // Tap Calendar tab
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      expect(find.text('Calendar & Routine'), findsOneWidget);

      // Tap Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Hide Completed Activities'), findsOneWidget);

      // Tap Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Student Profile'), findsOneWidget);
    });
  });
}
