import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/user_model.dart';

/// GreetingHeader displays:
/// - Avatar on left with "Hi [Name], Welcome back!"
/// - Notification Bell button on right with red alert badge
/// directly inspired by the mockup in Image 1.
class GreetingHeader extends StatelessWidget {
  final UserModel? user;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onNotificationTap;

  const GreetingHeader({
    super.key,
    required this.user,
    this.onAvatarTap,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasName = user != null && user!.name.trim().isNotEmpty;
    final firstName = hasName ? user!.name.trim().split(' ').first : 'Student';

    return Row(
      children: [
        // Left: User Circular Avatar
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryContainer,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Text Greeting: "Hi [Name]," / "Welcome back!"
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi $firstName,',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Welcome back!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),

        // Right: Notification Bell in sleek circular container with indicator dot
        Stack(
          children: [
            InkWell(
              onTap: onNotificationTap,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 22,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 11,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
