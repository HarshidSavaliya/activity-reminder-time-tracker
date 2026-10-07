import 'package:flutter/material.dart';
import '../core/constants/app_dimensions.dart';
import 'app_button.dart';

/// ConfirmationDialog presents clear, non-intrusive action confirmation.
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.isDestructive = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: AppDimensions.borderRadiusLg,
      ),
      backgroundColor: theme.colorScheme.surface,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      ),
      content: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
          height: 1.4,
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: AppButton(
                text: cancelText,
                variant: AppButtonVariant.outlined,
                height: 44,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: AppButton(
                text: confirmText,
                variant: isDestructive ? AppButtonVariant.danger : AppButtonVariant.primary,
                height: 44,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
