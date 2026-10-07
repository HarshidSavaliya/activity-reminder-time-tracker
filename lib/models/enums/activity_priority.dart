import 'package:flutter/material.dart';

enum PriorityLevel { low, medium, high }

enum ActivityPriority {
  low,
  medium,
  high;

  static ActivityPriority fromString(String? value) {
    if (value == null) return ActivityPriority.medium;
    return ActivityPriority.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ActivityPriority.medium,
    );
  }
}

extension ActivityPriorityExtension on ActivityPriority {
  PriorityLevel get priorityLevel {
    switch (this) {
      case ActivityPriority.low:
        return PriorityLevel.low;
      case ActivityPriority.medium:
        return PriorityLevel.medium;
      case ActivityPriority.high:
        return PriorityLevel.high;
    }
  }
  String get displayName {
    switch (this) {
      case ActivityPriority.low:
        return 'Low';
      case ActivityPriority.medium:
        return 'Medium';
      case ActivityPriority.high:
        return 'High';
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityPriority.low:
        return Icons.arrow_downward_rounded;
      case ActivityPriority.medium:
        return Icons.remove_rounded;
      case ActivityPriority.high:
        return Icons.priority_high_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ActivityPriority.low:
        return const Color(0xFF10B981); // Emerald
      case ActivityPriority.medium:
        return const Color(0xFFF59E0B); // Amber
      case ActivityPriority.high:
        return const Color(0xFFEF4444); // Crimson
    }
  }
}
