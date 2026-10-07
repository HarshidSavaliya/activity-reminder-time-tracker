import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/pdf_import_record.dart';
import 'storage_service.dart';

/// Service managing persistent history of imported PDF timetables per user.
class PdfHistoryService {
  final StorageService _storage;

  PdfHistoryService(dynamic storage)
      : _storage = storage is StorageService
            ? storage
            : (storage is SharedPreferences
                ? SharedPreferencesStorageService(storage)
                : storage as StorageService);

  String _getKey(String userId) => 'pdf_import_history_$userId';

  /// Retrieves all past import records for the specified user, sorted newest first.
  List<PdfImportRecord> getRecords(String userId) {
    final raw = _storage.getString(_getKey(userId));
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final records = list
          .map((item) => PdfImportRecord.fromJson(item as Map<String, dynamic>))
          .toList();
      records.sort((a, b) => b.importDate.compareTo(a.importDate));
      return records;
    } catch (_) {
      return [];
    }
  }

  /// Appends a new import record to the user's history log.
  Future<void> saveRecord(PdfImportRecord record) async {
    final records = getRecords(record.userId);
    records.insert(0, record);
    // Keep last 50 records to manage storage cleanly
    if (records.length > 50) {
      records.removeRange(50, records.length);
    }

    final raw = jsonEncode(records.map((r) => r.toJson()).toList());
    await _storage.setString(_getKey(record.userId), raw);
  }

  /// Deletes a specific history record by ID.
  Future<void> deleteRecord(String recordId, String userId) async {
    final records = getRecords(userId);
    records.removeWhere((r) => r.id == recordId);
    final raw = jsonEncode(records.map((r) => r.toJson()).toList());
    await _storage.setString(_getKey(userId), raw);
  }

  /// Clears all PDF history for a user.
  Future<void> clearHistory(String userId) async {
    await _storage.remove(_getKey(userId));
  }
}
