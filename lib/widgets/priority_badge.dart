import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_dimensions.dart';
import '../models/enums/activity_priority.dart';

export '../models/enums/activity_priority.dart' show PriorityLevel;

/// PriorityBadge renders an accessible pill tag indicating activity urgency,
/// paired with distinct icons for color-blind accessibility.
class PriorityBadge extends StatelessWidget {
  final dynamic priority; // Can be ActivityPriority or PriorityLevel
  final bool compact;

  const PriorityBadge({
    super.key,
    required this.priority,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String name = (priority is ActivityPriority)
        ? (priority as ActivityPriority).name.toLowerCase()
        : (priority is PriorityLevel)
            ? (priority as PriorityLevel).name.toLowerCase()
            : priority.toString().toLowerCase();

    final (Color color, Color bgColor, String label, IconData icon) = switch (name) {
      'high' => (
          AppColors.priorityHigh,
          isDark ? AppColors.priorityHighBgDark : AppColors.priorityHighBg,
          'High',
          Icons.priority_high_rounded,
        ),
      'low' => (
          AppColors.priorityLow,
          isDark ? AppColors.priorityLowBgDark : AppColors.priorityLowBg,
          'Low',
          Icons.arrow_downward_rounded,
        ),
      _ => (
          AppColors.priorityMedium,
          isDark ? AppColors.priorityMediumBgDark : AppColors.priorityMediumBg,
          'Medium',
          Icons.remove_rounded,
        ),
    };

    if (compact) {
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 10, color: color),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppDimensions.borderRadiusSm,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppDimensions.space4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
