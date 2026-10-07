import 'storage_service.dart';

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
