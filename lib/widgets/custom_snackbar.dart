import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_dimensions.dart';

/// CustomSnackbar provides clean, modern feedback messages without disruptive overlays,
/// with support for non-blocking Undo actions.
class CustomSnackbar {
  CustomSnackbar._();

  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      backgroundColor: AppColors.success,
    );
  }

  static void showError(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.error_rounded,
      backgroundColor: AppColors.error,
    );
  }

  static void showInfo(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.info_rounded,
      backgroundColor: AppColors.info,
    );
  }

  static void showAction(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    IconData icon = Icons.info_outline_rounded,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor ?? AppColors.neutral800,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusMd,
        ),
        margin: const EdgeInsets.all(AppDimensions.space16),
        duration: duration,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: AppDimensions.iconSizeSm + 2),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: actionLabel,
          textColor: AppColors.primary400,
          onPressed: onAction,
        ),
      ),
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
  }) {
    if (!context.mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusMd,
        ),
        margin: const EdgeInsets.all(AppDimensions.space16),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: AppDimensions.iconSizeSm + 2),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
