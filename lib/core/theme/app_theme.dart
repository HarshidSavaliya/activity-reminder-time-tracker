import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// AppTheme provides cohesive Material 3 Light and Dark themes.
/// Clean, human-designed, distraction-free aesthetics with strong readability.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: const Color(0xFF087F5B),
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textPrimaryLight,
      outline: AppColors.borderLight,
      outlineVariant: AppColors.dividerLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      fontFamily: null, // System default sans-serif for clean native feel
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryLight,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusMd,
          side: BorderSide(color: AppColors.borderLight, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
          shape: const RoundedRectangleBorder(
            borderRadius: AppDimensions.borderRadiusMd,
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
          side: const BorderSide(color: AppColors.borderLight, width: 1.2),
          shape: const RoundedRectangleBorder(
            borderRadius: AppDimensions.borderRadiusMd,
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: const RoundedRectangleBorder(
            borderRadius: AppDimensions.borderRadiusSm,
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space16,
        ),
        border: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textMutedLight,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondaryLight,
          fontSize: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMutedLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: AppColors.primaryLight,
      onPrimary: Colors.black,
      primaryContainer: AppColors.primaryContainerDark,
      onPrimaryContainer: AppColors.primaryLight,
      secondary: AppColors.secondary,
      onSecondary: Colors.black,
      secondaryContainer: const Color(0xFF143026),
      onSecondaryContainer: const Color(0xFF63E6BE),
      error: const Color(0xFFFF8787),
      onError: Colors.black,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textPrimaryDark,
      outline: AppColors.borderDark,
      outlineVariant: AppColors.dividerDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      fontFamily: null,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryDark,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusMd,
          side: BorderSide(color: AppColors.borderDark, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
          shape: const RoundedRectangleBorder(
            borderRadius: AppDimensions.borderRadiusMd,
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
          side: const BorderSide(color: AppColors.borderDark, width: 1.2),
          shape: const RoundedRectangleBorder(
            borderRadius: AppDimensions.borderRadiusMd,
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          shape: const RoundedRectangleBorder(
            borderRadius: AppDimensions.borderRadiusSm,
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space16,
        ),
        border: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMd,
          borderSide: const BorderSide(color: Color(0xFFFF8787), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusMd,
          borderSide: const BorderSide(color: Color(0xFFFF8787), width: 1.6),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textMutedDark,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: AppColors.textMutedDark,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}
