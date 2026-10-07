import 'package:shared_preferences/shared_preferences.dart';

/// Abstract persistent storage interface decoupling the application from SharedPreferences
/// and enabling isolated, mockable unit and integration tests.
abstract class StorageService {
  String? getString(String key);
  Future<bool> setString(String key, String value);

  List<String>? getStringList(String key);
  Future<bool> setStringList(String key, List<String> value);

  bool? getBool(String key);
  Future<bool> setBool(String key, bool value);

  int? getInt(String key);
  Future<bool> setInt(String key, int value);

  double? getDouble(String key);
  Future<bool> setDouble(String key, double value);

  Future<bool> remove(String key);
  Future<bool> clear();
  bool containsKey(String key);
}

/// Concrete implementation of [StorageService] backed by [SharedPreferences].
class SharedPreferencesStorageService implements StorageService {
  final SharedPreferences _prefs;

  SharedPreferencesStorageService(this._prefs);

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<bool> setString(String key, String value) => _prefs.setString(key, value);

  @override
  List<String>? getStringList(String key) => _prefs.getStringList(key);

  @override
  Future<bool> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  int? getInt(String key) => _prefs.getInt(key);

  @override
  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  @override
  double? getDouble(String key) => _prefs.getDouble(key);

  @override
  Future<bool> setDouble(String key, double value) => _prefs.setDouble(key, value);

  @override
  Future<bool> remove(String key) => _prefs.remove(key);

  @override
  Future<bool> clear() => _prefs.clear();

  @override
  bool containsKey(String key) => _prefs.containsKey(key);
}

/// Fast, dependency-free in-memory implementation of [StorageService] for unit testing.
class InMemoryStorageService implements StorageService {
  final Map<String, dynamic> _storage = {};

  InMemoryStorageService([Map<String, dynamic>? initialValues]) {
    if (initialValues != null) {
      _storage.addAll(initialValues);
    }
  }

  @override
  String? getString(String key) => _storage[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    _storage[key] = value;
    return true;
  }

  @override
  List<String>? getStringList(String key) =>
      (_storage[key] as List<dynamic>?)?.map((e) => e.toString()).toList();

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _storage[key] = List<String>.from(value);
    return true;
  }

  @override
  bool? getBool(String key) => _storage[key] as bool?;

  @override
  Future<bool> setBool(String key, bool value) async {
    _storage[key] = value;
    return true;
  }

  @override
  int? getInt(String key) => _storage[key] as int?;

  @override
  Future<bool> setInt(String key, int value) async {
    _storage[key] = value;
    return true;
  }

  @override
  double? getDouble(String key) => _storage[key] as double?;

  @override
  Future<bool> setDouble(String key, double value) async {
    _storage[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _storage.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _storage.clear();
    return true;
  }

  @override
  bool containsKey(String key) => _storage.containsKey(key);
}
