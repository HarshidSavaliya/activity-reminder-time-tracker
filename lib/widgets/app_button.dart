import 'package:flutter/material.dart';
import '../core/constants/app_dimensions.dart';

enum AppButtonVariant { primary, outlined, text, danger }

/// A reusable, production-ready button supporting multiple variants, loading states, and icons.
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = AppDimensions.buttonHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget child;
    if (isLoading) {
      child = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(
            variant == AppButtonVariant.primary
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.primary,
          ),
        ),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: AppDimensions.iconSizeSm),
          const SizedBox(width: AppDimensions.space8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else {
      child = Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final buttonStyle = switch (variant) {
      AppButtonVariant.primary => ElevatedButton.styleFrom(
          minimumSize: Size(width ?? 0, height),
        ),
      AppButtonVariant.outlined => OutlinedButton.styleFrom(
          minimumSize: Size(width ?? 0, height),
        ),
      AppButtonVariant.text => TextButton.styleFrom(
          minimumSize: Size(width ?? 0, height),
        ),
      AppButtonVariant.danger => ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.error,
          foregroundColor: theme.colorScheme.onError,
          minimumSize: Size(width ?? 0, height),
        ),
    };

    final effectiveOnPressed = isLoading ? null : onPressed;

    Widget button = switch (variant) {
      AppButtonVariant.primary || AppButtonVariant.danger => ElevatedButton(
          onPressed: effectiveOnPressed,
          style: buttonStyle,
          child: child,
        ),
      AppButtonVariant.outlined => OutlinedButton(
          onPressed: effectiveOnPressed,
          style: buttonStyle,
          child: child,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: effectiveOnPressed,
          style: buttonStyle,
          child: child,
        ),
    };

    if (width != null) {
      return SizedBox(width: width, child: button);
    }
    return button;
  }
}
