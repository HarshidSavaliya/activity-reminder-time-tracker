import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_keys.dart';
import '../core/services/storage_service.dart';

/// ThemeProvider manages the application's visual theme mode
/// and automatically synchronizes preferences with persistent local storage.
class ThemeProvider extends ChangeNotifier {
  final StorageService? _storage;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider([dynamic storage])
      : _storage = storage == null
            ? null
            : (storage is StorageService
                ? storage
                : (storage is SharedPreferences
                    ? SharedPreferencesStorageService(storage)
                    : storage as StorageService)) {
    _loadThemeMode();
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  void _loadThemeMode() {
    final savedMode = _storage?.getString(AppKeys.themeMode);
    if (savedMode == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedMode == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    if (_storage != null) {
      String value = 'system';
      if (mode == ThemeMode.light) value = 'light';
      if (mode == ThemeMode.dark) value = 'dark';
      await _storage.setString(AppKeys.themeMode, value);
    }
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }
}

/// Backwards compatibility alias
typedef ThemeController = ThemeProvider;
