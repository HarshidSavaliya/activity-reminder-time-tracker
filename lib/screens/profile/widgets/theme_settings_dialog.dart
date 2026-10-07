import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/app_button.dart';

/// ThemeSettingsDialog allows users to toggle between System, Light, and Dark themes.
class ThemeSettingsDialog extends StatelessWidget {
  const ThemeSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const ThemeSettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeProvider>();
    final currentMode = themeCtrl.themeMode;

    return AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: AppDimensions.borderRadiusLg,
      ),
      title: const Text(
        'Appearance & Theme',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildThemeOption(
              context: context,
              title: 'System Default',
              description: 'Follows operating system settings',
              icon: Icons.brightness_auto_rounded,
              isSelected: currentMode == ThemeMode.system,
              onTap: () => themeCtrl.setThemeMode(ThemeMode.system),
            ),
            const SizedBox(height: AppDimensions.space8),
            _buildThemeOption(
              context: context,
              title: 'Light Theme',
              description: 'Clean surface with indigo accents',
              icon: Icons.light_mode_rounded,
              isSelected: currentMode == ThemeMode.light,
              onTap: () => themeCtrl.setThemeMode(ThemeMode.light),
            ),
            const SizedBox(height: AppDimensions.space8),
            _buildThemeOption(
              context: context,
              title: 'Dark Theme',
              description: 'Sleek dark surface designed for night reading',
              icon: Icons.dark_mode_rounded,
              isSelected: currentMode == ThemeMode.dark,
              onTap: () => themeCtrl.setThemeMode(ThemeMode.dark),
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          text: 'Done',
          height: 42,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: AppDimensions.borderRadiusMd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: AppDimensions.borderRadiusMd,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
