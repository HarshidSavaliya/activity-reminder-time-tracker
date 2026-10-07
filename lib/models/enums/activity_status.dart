import 'package:flutter/material.dart';

enum ActivityStatus {
  pending,
  completed,
  cancelled,
  skipped;

  static ActivityStatus fromString(String? value) {
    if (value == null) return ActivityStatus.pending;
    return ActivityStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ActivityStatus.pending,
    );
  }
}

extension ActivityStatusExtension on ActivityStatus {
  String get displayName {
    switch (this) {
      case ActivityStatus.pending:
        return 'Pending';
      case ActivityStatus.completed:
        return 'Completed';
      case ActivityStatus.cancelled:
        return 'Cancelled';
      case ActivityStatus.skipped:
        return 'Skipped';
    }
  }

  Color get color {
    switch (this) {
      case ActivityStatus.pending:
        return const Color(0xFFF59E0B); // Amber
      case ActivityStatus.completed:
        return const Color(0xFF10B981); // Emerald
      case ActivityStatus.cancelled:
        return const Color(0xFFEF4444); // Crimson
      case ActivityStatus.skipped:
        return const Color(0xFF6B7280); // Gray
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityStatus.pending:
        return Icons.hourglass_top_rounded;
      case ActivityStatus.completed:
        return Icons.check_circle_rounded;
      case ActivityStatus.cancelled:
        return Icons.cancel_rounded;
      case ActivityStatus.skipped:
        return Icons.redo_rounded;
    }
  }
}
