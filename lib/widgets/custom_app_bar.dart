import 'package:flutter/material.dart';
import '../core/constants/app_dimensions.dart';

/// CustomAppBar provides uniform header typography, optional subtitle, and actions.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final double elevation;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.elevation = 0,
  });

  @override
  Size get preferredSize => Size.fromHeight(subtitle != null ? 68.0 : kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      elevation: elevation,
      centerTitle: centerTitle,
      leading: leading,
      title: Column(
        crossAxisAlignment: centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppDimensions.space2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
      actions: actions,
    );
  }
}
