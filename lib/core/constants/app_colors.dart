import 'package:flutter/material.dart';

/// AppColors defines a curated, human-designed, high-contrast color palette.
/// Avoids generic AI gradients and neon colors; uses professional, calm indigo
/// and slate tones with clear semantic indicators.
class AppColors {
  AppColors._();

  // Primary brand palette (Modern Vibrant Purple & Indigo from design references)
  static const Color primary = Color(0xFF7C5CE9);
  static const Color primaryDark = Color(0xFF5B3CC4);
  static const Color primaryLight = Color(0xFF9F85F7);
  static const Color primary400 = Color(0xFF8B5CF6);
  static const Color primaryContainer = Color(0xFFF3F0FE);
  static const Color primaryContainerDark = Color(0xFF221F38);
  static const Color neutral800 = Color(0xFF1E222B);

  // Status Summary Colors (Directly matching Image 1 2x2 Grid)
  static const Color statusTodo = Color(0xFF8B5CF6);           // Purple Card
  static const Color statusTodoBg = Color(0xFFEDE9FE);
  static const Color statusInProgress = Color(0xFFF5B942);     // Warm Amber/Yellow Card
  static const Color statusInProgressBg = Color(0xFFFEF3C7);
  static const Color statusInReview = Color(0xFFF472B6);       // Soft Pastel Pink Card
  static const Color statusInReviewBg = Color(0xFFFCE7F3);
  static const Color statusComplete = Color(0xFF10B981);       // Emerald Green Card
  static const Color statusCompleteBg = Color(0xFFD1FAE5);

  // Chart Spline Colors (From Task Statistics chart in Image 1)
  static const Color chartProgress = Color(0xFFF5B942);
  static const Color chartReview = Color(0xFFF472B6);
  static const Color chartComplete = Color(0xFF10B981);

  // Floating Pill Navigation Bar
  static const Color floatingNavBg = Color(0xFF14131B);
  static const Color floatingNavActive = Color(0xFF2A273C);

  // Secondary & Accent
  static const Color secondary = Color(0xFF10B981);
  static const Color secondaryContainer = Color(0xFFD1FAE5);

  // Semantic Priority Colors
  static const Color priorityHigh = Color(0xFFEF4444);
  static const Color priorityHighBg = Color(0xFFFEE2E2);
  static const Color priorityHighBgDark = Color(0xFF3B1818);

  static const Color priorityMedium = Color(0xFFF59E0B);
  static const Color priorityMediumBg = Color(0xFFFEF3C7);
  static const Color priorityMediumBgDark = Color(0xFF3B2E10);

  static const Color priorityLow = Color(0xFF10B981);
  static const Color priorityLowBg = Color(0xFFD1FAE5);
  static const Color priorityLowBgDark = Color(0xFF122E1A);

  // Neutral / Background Colors - Light Mode
  static const Color backgroundLight = Color(0xFFF8F9FE);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF13111C);
  static const Color textSecondaryLight = Color(0xFF4B4F5E);
  static const Color textMutedLight = Color(0xFF8E93A6);
  static const Color dividerLight = Color(0xFFEEEEF5);
  static const Color borderLight = Color(0xFFE5E7EB);

  // Neutral / Background Colors - Dark Mode
  static const Color backgroundDark = Color(0xFF0F0E17);
  static const Color surfaceDark = Color(0xFF181622);
  static const Color cardDark = Color(0xFF1E1C2B);
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFFD1D5DB);
  static const Color textMutedDark = Color(0xFF9CA3AF);
  static const Color dividerDark = Color(0xFF262436);
  static const Color borderDark = Color(0xFF2E2B40);

  // Status & Utility Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
}
