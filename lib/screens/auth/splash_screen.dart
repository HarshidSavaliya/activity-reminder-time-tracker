import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/activity_provider.dart';
import '../../providers/auth_provider.dart';

/// SplashScreen verifies user authentication session and routes appropriately.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      final user = auth.currentUser!;
      await context.read<ActivityProvider>().loadActivities(user.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.main);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppDimensions.borderRadiusLg,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.alarm_on_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: AppDimensions.space20),
            const Text(
              AppStrings.appName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppDimensions.space4),
            Text(
              AppStrings.appTagline,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
