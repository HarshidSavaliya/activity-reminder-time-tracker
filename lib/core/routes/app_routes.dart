import 'package:flutter/material.dart';
import '../../models/activity_model.dart';
import '../../screens/activities/activity_detail_screen.dart';
import '../../screens/activities/add_edit_activity_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/splash_screen.dart';
import '../../screens/main_navigation_shell.dart';
import '../../screens/calendar/calendar_screen.dart';
import '../../screens/pdf_import/pdf_import_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/settings/settings_screen.dart';

/// AppRoutes declares all application destination paths and centralizes routing logic.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String main = '/main';
  static const String activityForm = '/activity-form';
  static const String activityDetail = '/activity-detail';
  static const String pdfImport = '/pdf-import';
  static const String calendar = '/calendar';
  static const String profile = '/profile';
  static const String settings = '/settings';

  static Route<dynamic> onGenerateRoute(RouteSettings settingsArgs) {
    switch (settingsArgs.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());

      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());

      case main:
        return MaterialPageRoute(builder: (_) => const MainNavigationShell());

      case calendar:
        return MaterialPageRoute(builder: (_) => const CalendarScreen());

      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());

      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());

      case activityForm:
        final existingActivity = settingsArgs.arguments as ActivityModel?;
        return MaterialPageRoute(
          builder: (_) => AddEditActivityScreen(existingActivity: existingActivity),
        );

      case activityDetail:
        final activity = settingsArgs.arguments as ActivityModel;
        return MaterialPageRoute(
          builder: (_) => ActivityDetailScreen(activity: activity),
        );

      case pdfImport:
        return MaterialPageRoute(builder: (_) => const PdfImportScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settingsArgs.name}'),
            ),
          ),
        );
    }
  }
}
