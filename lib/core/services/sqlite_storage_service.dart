import 'dart:convert';
import '../database/app_database.dart';
import 'storage_service.dart';

/// Concrete [StorageService] implementation backed by the SQLite `app_settings` table.
/// Maintains an in-memory synchronized cache for instantaneous synchronous reads while
/// asynchronously persisting all updates directly to SQLite.
class SqliteStorageService implements StorageService {
  final AppDatabase _db;
  final Map<String, dynamic> _cache = {};
  bool _isLoaded = false;

  SqliteStorageService([AppDatabase? database]) : _db = database ?? AppDatabase.instance;

  /// Loads all persistent settings from SQLite into the fast synchronous memory cache.
  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final settings = await _db.getAllSettings();
      for (final entry in settings.entries) {
        _cache[entry.key] = entry.value;
      }
      _isLoaded = true;
    } catch (_) {
      // In testing environments without active SQLite files, cache operates in-memory
      _isLoaded = true;
    }
  }

  /// AppDatabase reference for direct relational queries
  AppDatabase get db => _db;

  @override
  String? getString(String key) {
    final val = _cache[key];
    if (val == null) return null;
    return val.toString();
  }

  @override
  Future<bool> setString(String key, String value) async {
    _cache[key] = value;
    try {
      await _db.setSetting(key, value);
    } catch (_) {}
    return true;
  }

  @override
  List<String>? getStringList(String key) {
    final raw = getString(key);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return list.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    final jsonStr = jsonEncode(value);
    return setString(key, jsonStr);
  }

  @override
  bool? getBool(String key) {
    final val = getString(key);
    if (val == null) return null;
    return val == 'true' || val == '1';
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    return setString(key, value.toString());
  }

  @override
  int? getInt(String key) {
    final val = getString(key);
    if (val == null) return null;
    return int.tryParse(val);
  }

  @override
  Future<bool> setInt(String key, int value) async {
    return setString(key, value.toString());
  }

  @override
  double? getDouble(String key) {
    final val = getString(key);
    if (val == null) return null;
    return double.tryParse(val);
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    return setString(key, value.toString());
  }

  @override
  Future<bool> remove(String key) async {
    _cache.remove(key);
    try {
      await _db.deleteSetting(key);
    } catch (_) {}
    return true;
  }

  @override
  Future<bool> clear() async {
    _cache.clear();
    try {
      final db = await _db.database;
      await db.delete('app_settings');
    } catch (_) {}
    return true;
  }

  @override
  bool containsKey(String key) => _cache.containsKey(key);
}
