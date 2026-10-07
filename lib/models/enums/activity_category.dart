import 'package:flutter/material.dart';

/// Categories for activities in Activity Reminder Tracker.
/// Designed for general purpose daily routines, professional work, fitness, and study.
enum ActivityCategory {
  work,
  health,
  personal,
  meeting,
  study,
  routine,
  lecture,
  lab,
  assignment,
  exam;

  static ActivityCategory fromString(String? value) {
    if (value == null) return ActivityCategory.personal;
    final lower = value.toLowerCase().trim();
    if (lower == 'fitness' || lower == 'gym' || lower == 'exercise' || lower == 'workout') {
      return ActivityCategory.health;
    }
    if (lower == 'office' || lower == 'job' || lower == 'project') {
      return ActivityCategory.work;
    }
    if (lower == 'habit' || lower == 'daily') {
      return ActivityCategory.routine;
    }
    return ActivityCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == lower,
      orElse: () => ActivityCategory.personal,
    );
  }
}

extension ActivityCategoryExtension on ActivityCategory {
  String get displayName {
    switch (this) {
      case ActivityCategory.work:
        return 'Work';
      case ActivityCategory.health:
        return 'Health & Fitness';
      case ActivityCategory.personal:
        return 'Personal';
      case ActivityCategory.meeting:
        return 'Meeting';
      case ActivityCategory.study:
        return 'Study';
      case ActivityCategory.routine:
        return 'Routine';
      case ActivityCategory.lecture:
        return 'Lecture';
      case ActivityCategory.lab:
        return 'Lab';
      case ActivityCategory.assignment:
        return 'Assignment';
      case ActivityCategory.exam:
        return 'Exam';
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityCategory.work:
        return Icons.work_rounded;
      case ActivityCategory.health:
        return Icons.fitness_center_rounded;
      case ActivityCategory.personal:
        return Icons.person_rounded;
      case ActivityCategory.meeting:
        return Icons.groups_rounded;
      case ActivityCategory.study:
        return Icons.menu_book_rounded;
      case ActivityCategory.routine:
        return Icons.repeat_rounded;
      case ActivityCategory.lecture:
        return Icons.school_rounded;
      case ActivityCategory.lab:
        return Icons.science_rounded;
      case ActivityCategory.assignment:
        return Icons.assignment_rounded;
      case ActivityCategory.exam:
        return Icons.quiz_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ActivityCategory.work:
        return const Color(0xFF0284C7); // Sky Blue
      case ActivityCategory.health:
        return const Color(0xFF10B981); // Emerald
      case ActivityCategory.personal:
        return const Color(0xFF059669); // Green
      case ActivityCategory.meeting:
        return const Color(0xFF4F46E5); // Indigo
      case ActivityCategory.study:
        return const Color(0xFF7C3AED); // Purple
      case ActivityCategory.routine:
        return const Color(0xFF8B5CF6); // Violet
      case ActivityCategory.lecture:
        return const Color(0xFF2563EB); // Blue
      case ActivityCategory.lab:
        return const Color(0xFF0D9488); // Teal
      case ActivityCategory.assignment:
        return const Color(0xFFD97706); // Amber
      case ActivityCategory.exam:
        return const Color(0xFFDC2626); // Red
    }
  }
}
