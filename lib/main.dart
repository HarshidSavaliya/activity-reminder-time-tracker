import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_strings.dart';
import 'core/database/app_database.dart';
import 'core/routes/app_routes.dart';
import 'core/services/activity_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/pdf_history_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'providers/activity_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/pdf_import_provider.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite Persistent Database Engine
  final appDb = AppDatabase.instance;
  try {
    await appDb.initDatabase();
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();
  final storageService = SharedPreferencesStorageService(prefs);

  final authService = AuthService(storageService);
  await authService.seedInitialDemoUserIfNeeded();

  final notificationService = NotificationService(storageService);
  final activityService = ActivityService(storageService, appDb);
  final historyService = PdfHistoryService(storageService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(storageService)),
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        ChangeNotifierProvider(
          create: (_) => ActivityProvider(activityService, notificationService),
        ),
        ChangeNotifierProvider(
          create: (_) => PdfImportProvider(
            historyService: historyService,
          ),
        ),
      ],
      child: const ActivityReminderTrackerApp(),
    ),
  );
}

class ActivityReminderTrackerApp extends StatelessWidget {
  const ActivityReminderTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeProvider>();

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeCtrl.themeMode,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
