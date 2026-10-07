import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/activity_model.dart';
import '../../models/pdf_import_record.dart';
import '../../models/user_model.dart';

/// Central SQLite Database management service for Activity Reminder Tracker.
/// Provides persistent offline storage for Activities, User Sessions, PDF History, and Key-Value Settings.
class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  AppDatabase._internal();

  Database? _db;
  bool _initializedFfi = false;

  /// Returns whether database is currently open.
  bool get isOpen => _db != null && _db!.isOpen;

  /// Ensures SQLite FFI is initialized on desktop platforms (Windows, Linux, macOS).
  void _ensureFfiInitialized() {
    if (_initializedFfi) return;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _initializedFfi = true;
    }
  }

  /// Retrieves the active SQLite database instance, opening it if necessary.
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await initDatabase();
    return _db!;
  }

  /// Initializes the SQLite database file and executes migration schema.
  Future<Database> initDatabase({String? customPath, bool inMemory = false}) async {
    _ensureFfiInitialized();

    String dbPath;
    if (inMemory) {
      dbPath = inMemoryDatabasePath;
    } else if (customPath != null) {
      dbPath = customPath;
    } else {
      final defaultDbDir = await getDatabasesPath();
      dbPath = p.join(defaultDbDir, 'activity_reminder_tracker.db');
    }

    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: _createDatabase,
    );

    _db = db;
    return db;
  }

  Future<void> _createDatabase(Database db, int version) async {
    // 1. Activities Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activities (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        priority TEXT NOT NULL,
        status TEXT NOT NULL,
        reminder_json TEXT,
        recurrence_json TEXT,
        location TEXT,
        source TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        completed_at TEXT,
        recurrence_parent_id TEXT,
        occurrence_date TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_activities_user ON activities (user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_activities_date ON activities (date)');

    // 2. Users Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        username TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        college TEXT,
        student_id TEXT,
        bio TEXT,
        avatar_seed TEXT,
        reminders_enabled INTEGER NOT NULL DEFAULT 1,
        daily_digest_enabled INTEGER NOT NULL DEFAULT 1,
        sound_enabled INTEGER NOT NULL DEFAULT 1,
        vibration_enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_users_email ON users (email)');

    // 3. PDF Import History Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pdf_import_history (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        filename TEXT NOT NULL,
        file_size_bytes INTEGER NOT NULL,
        import_date TEXT NOT NULL,
        total_detected INTEGER NOT NULL,
        imported_count INTEGER NOT NULL,
        skipped_count INTEGER NOT NULL,
        status TEXT NOT NULL,
        activity_titles_json TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pdf_history_user ON pdf_import_history (user_id)');

    // 4. Key-Value App Settings & Metadata Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ==================== ACTIVITY CRUD OPERATIONS ====================

  Future<void> insertActivity(ActivityModel activity) async {
    final db = await database;
    await db.insert(
      'activities',
      _activityToMap(activity),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertActivities(List<ActivityModel> activities) async {
    if (activities.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final act in activities) {
      batch.insert(
        'activities',
        _activityToMap(act),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateActivity(ActivityModel activity) async {
    final db = await database;
    await db.update(
      'activities',
      _activityToMap(activity),
      where: 'id = ? AND user_id = ?',
      whereArgs: [activity.id, activity.userId],
    );
  }

  Future<void> deleteActivity(String id, String userId) async {
    final db = await database;
    await db.delete(
      'activities',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  Future<ActivityModel?> getActivityById(String id) async {
    final db = await database;
    final rows = await db.query(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _activityFromMap(rows.first);
  }

  Future<List<ActivityModel>> getActivities(String userId) async {
    final db = await database;
    final rows = await db.query(
      'activities',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'start_time ASC',
    );
    return rows.map(_activityFromMap).toList();
  }

  Future<void> replaceUserActivities(String userId, List<ActivityModel> activities) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('activities', where: 'user_id = ?', whereArgs: [userId]);
      final batch = txn.batch();
      for (final a in activities) {
        batch.insert('activities', _activityToMap(a));
      }
      await batch.commit(noResult: true);
    });
  }

  // ==================== USER CRUD OPERATIONS ====================

  Future<void> insertUser(UserModel user) async {
    final db = await database;
    await db.insert(
      'users',
      {
        'id': user.id,
        'name': user.name,
        'username': user.username,
        'email': user.email.toLowerCase(),
        'password': user.password,
        'college': user.college,
        'student_id': user.studentId,
        'bio': user.bio,
        'avatar_seed': user.avatarSeed,
        'reminders_enabled': user.remindersEnabled ? 1 : 0,
        'daily_digest_enabled': user.dailyDigestEnabled ? 1 : 0,
        'sound_enabled': user.soundEnabled ? 1 : 0,
        'vibration_enabled': user.vibrationEnabled ? 1 : 0,
        'created_at': user.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.toLowerCase().trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _userFromMap(rows.first);
  }

  Future<UserModel?> getUserById(String id) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _userFromMap(rows.first);
  }

  Future<UserModel?> getUserByUsername(String username) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _userFromMap(rows.first);
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final rows = await db.query('users');
    return rows.map(_userFromMap).toList();
  }

  // ==================== PDF HISTORY OPERATIONS ====================

  Future<void> insertPdfRecord(PdfImportRecord record) async {
    final db = await database;
    await db.insert(
      'pdf_import_history',
      {
        'id': record.id,
        'user_id': record.userId,
        'filename': record.filename,
        'file_size_bytes': record.fileSizeBytes,
        'import_date': record.importDate.toIso8601String(),
        'total_detected': record.totalDetected,
        'imported_count': record.importedCount,
        'skipped_count': record.skippedCount,
        'status': record.status,
        'activity_titles_json': jsonEncode(record.activityTitles),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PdfImportRecord>> getPdfRecords(String userId) async {
    final db = await database;
    final rows = await db.query(
      'pdf_import_history',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'import_date DESC',
    );
    return rows.map((map) {
      List<String> titles = [];
      if (map['activity_titles_json'] != null) {
        try {
          final decoded = jsonDecode(map['activity_titles_json'] as String);
          if (decoded is List) {
            titles = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }

      return PdfImportRecord(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        filename: map['filename'] as String,
        fileSizeBytes: map['file_size_bytes'] as int? ?? 0,
        importDate: DateTime.parse(map['import_date'] as String),
        totalDetected: map['total_detected'] as int? ?? 0,
        importedCount: map['imported_count'] as int? ?? 0,
        skippedCount: map['skipped_count'] as int? ?? 0,
        status: map['status'] as String? ?? 'Imported',
        activityTitles: titles,
      );
    }).toList();
  }

  Future<void> deletePdfRecord(String id, String userId) async {
    final db = await database;
    await db.delete(
      'pdf_import_history',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  // ==================== APP SETTINGS & KEY-VALUE STORE ====================

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSetting(String key) async {
    final db = await database;
    await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final rows = await db.query('app_settings');
    final map = <String, String>{};
    for (final r in rows) {
      final k = r['key'] as String?;
      final v = r['value'] as String?;
      if (k != null && v != null) {
        map[k] = v;
      }
    }
    return map;
  }

  /// Returns total counts of stored entities in the SQLite database.
  Future<Map<String, int>> getStats() async {
    final db = await database;
    final actCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM activities')) ?? 0;
    final userCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users')) ?? 0;
    final histCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM pdf_import_history')) ?? 0;
    final settingsCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM app_settings')) ?? 0;
    return {
      'activities': actCount,
      'users': userCount,
      'pdf_imports': histCount,
      'settings': settingsCount,
    };
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  // ==================== PRIVATE SERIALIZATION HELPERS ====================

  Map<String, dynamic> _activityToMap(ActivityModel a) {
    return {
      'id': a.id,
      'user_id': a.userId,
      'title': a.title,
      'description': a.description,
      'category': a.category.name,
      'date': a.date.toIso8601String(),
      'start_time': a.startTime.toIso8601String(),
      'end_time': a.endTime?.toIso8601String(),
      'priority': a.priority.name,
      'status': a.status.name,
      'reminder_json': jsonEncode(a.reminder.toJson()),
      'recurrence_json': jsonEncode(a.recurrence.toJson()),
      'location': a.location,
      'source': a.source.name,
      'created_at': a.createdAt.toIso8601String(),
      'updated_at': a.updatedAt.toIso8601String(),
      'completed_at': a.completedAt?.toIso8601String(),
      'recurrence_parent_id': a.recurrenceParentId,
      'occurrence_date': a.occurrenceDate?.toIso8601String(),
    };
  }

  ActivityModel _activityFromMap(Map<String, dynamic> map) {
    final json = {
      'id': map['id'],
      'userId': map['user_id'],
      'title': map['title'],
      'description': map['description'] ?? '',
      'category': map['category'],
      'date': map['date'],
      'startTime': map['start_time'],
      'endTime': map['end_time'],
      'priority': map['priority'],
      'status': map['status'],
      'reminder': map['reminder_json'] != null ? jsonDecode(map['reminder_json'] as String) : null,
      'recurrence': map['recurrence_json'] != null ? jsonDecode(map['recurrence_json'] as String) : null,
      'location': map['location'] ?? '',
      'source': map['source'],
      'createdAt': map['created_at'],
      'updatedAt': map['updated_at'],
      'completedAt': map['completed_at'],
      'recurrenceParentId': map['recurrence_parent_id'],
      'occurrenceDate': map['occurrence_date'],
    };
    return ActivityModel.fromJson(json);
  }

  UserModel _userFromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      name: map['name'] as String,
      username: map['username'] as String,
      email: map['email'] as String,
      password: map['password'] as String,
      college: map['college'] as String? ?? 'General Routine Hub',
      studentId: map['student_id'] as String? ?? 'USR-2026',
      bio: map['bio'] as String? ?? 'Organizing daily activities, habits and schedules',
      avatarSeed: map['avatar_seed'] as String? ?? '1',
      remindersEnabled: (map['reminders_enabled'] as int? ?? 1) == 1,
      dailyDigestEnabled: (map['daily_digest_enabled'] as int? ?? 1) == 1,
      soundEnabled: (map['sound_enabled'] as int? ?? 1) == 1,
      vibrationEnabled: (map['vibration_enabled'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
