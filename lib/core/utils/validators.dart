import '../constants/app_strings.dart';

/// Form validation helper functions
class Validators {
  Validators._();

  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.emailRequired;
    }
    if (!_emailRegExp.hasMatch(value.trim())) {
      return AppStrings.emailInvalid;
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.passwordRequired;
    }
    if (value.length < 8) {
      return AppStrings.passwordTooShort;
    }
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(value);
    final hasDigit = RegExp(r'[0-9]').hasMatch(value);
    if (!hasLetter || !hasDigit) {
      return AppStrings.passwordNeedsComplexity;
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return AppStrings.passwordsDoNotMatch;
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.nameRequired;
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.usernameRequired;
    }
    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(value.trim())) {
      return 'Username can only contain letters, numbers, dots, and underscores';
    }
    return null;
  }

  static String? validateActivityTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.titleRequired;
    }
    if (value.trim().length < 3) {
      return 'Title must be at least 3 characters';
    }
    return null;
  }
}
