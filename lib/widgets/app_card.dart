import 'package:flutter/material.dart';
import '../core/constants/app_dimensions.dart';

/// AppCard is a human-designed, minimalist container with clean borders and subtle elevation.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;

  const AppCard({
    super.key,
    required this.child,
    this.padding = AppDimensions.cardPadding,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveRadius = borderRadius ?? AppDimensions.borderRadiusMd;

    Widget cardContent = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.cardTheme.color,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: borderColor ?? theme.colorScheme.outline,
          width: 1,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: effectiveRadius,
        child: InkWell(
          borderRadius: effectiveRadius,
          onTap: onTap,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
