import 'package:flutter/material.dart';
import '../core/constants/app_dimensions.dart';
import 'app_button.dart';

/// EmptyStateView presents human-designed empty states that guide the user gracefully.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final bool compact;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: compact ? AppDimensions.padding16 : AppDimensions.padding32,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: compact ? 56 : 72,
              height: compact ? 56 : 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: compact ? 28 : 36,
                color: theme.colorScheme.primary,
              ),
            ),
            SizedBox(height: compact ? AppDimensions.space12 : AppDimensions.space20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 15 : 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 13 : 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                height: 1.4,
              ),
            ),
            if (actionText != null && onAction != null) ...[
              SizedBox(height: compact ? AppDimensions.space16 : AppDimensions.space24),
              AppButton(
                text: actionText!,
                onPressed: onAction,
                width: compact ? 160 : 200,
                height: compact ? 42 : AppDimensions.buttonHeight,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
