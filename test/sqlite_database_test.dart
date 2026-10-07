import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:activity_reminder_tracker/core/database/app_database.dart';
import 'package:activity_reminder_tracker/core/services/sqlite_storage_service.dart';
import 'package:activity_reminder_tracker/models/activity_model.dart';
import 'package:activity_reminder_tracker/models/enums/activity_category.dart';
import 'package:activity_reminder_tracker/models/enums/activity_priority.dart';
import 'package:activity_reminder_tracker/models/enums/activity_source.dart';
import 'package:activity_reminder_tracker/models/enums/activity_status.dart';
import 'package:activity_reminder_tracker/models/pdf_import_record.dart';
import 'package:activity_reminder_tracker/models/recurrence_rule.dart';
import 'package:activity_reminder_tracker/models/reminder_setting.dart';
import 'package:activity_reminder_tracker/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.instance;
    await db.initDatabase(inMemory: true);
  });

  tearDown(() async {
    await db.close();
  });

  group('SQLite AppDatabase Tests', () {
    test('1. Database initializes successfully and is open', () {
      expect(db.isOpen, isTrue);
    });

    test('2. Insert, query, update, and delete Activity in SQLite', () async {
      final now = DateTime(2026, 10, 1, 9, 0);
      final activity = ActivityModel(
        id: 'act-sqlite-001',
        userId: 'user-001',
        title: 'Project Architecture Review',
        description: 'Review SQLite schema & Adobe PDF parser',
        category: ActivityCategory.work,
        date: now,
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        priority: ActivityPriority.high,
        status: ActivityStatus.pending,
        reminder: const ReminderSetting(),
        recurrence: const RecurrenceRule(),
        location: 'Room 402',
        source: ActivitySource.manual,
        createdAt: now,
        updatedAt: now,
      );

      // Insert
      await db.insertActivity(activity);

      // Query
      final retrieved = await db.getActivityById('act-sqlite-001');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Project Architecture Review');
      expect(retrieved.category, ActivityCategory.work);
      expect(retrieved.priority, ActivityPriority.high);
      expect(retrieved.location, 'Room 402');

      // Update
      final updated = retrieved.copyWith(
        title: 'Updated Architecture Review',
        status: ActivityStatus.completed,
      );
      await db.updateActivity(updated);

      final reFetched = await db.getActivityById('act-sqlite-001');
      expect(reFetched!.title, 'Updated Architecture Review');
      expect(reFetched.status, ActivityStatus.completed);

      // Delete
      await db.deleteActivity('act-sqlite-001', 'user-001');
      final afterDelete = await db.getActivityById('act-sqlite-001');
      expect(afterDelete, isNull);
    });

    test('3. Query activities by user ID', () async {
      final baseDate = DateTime(2026, 10, 1);
      final act1 = ActivityModel(
        id: 'act-range-1',
        userId: 'user-range-test',
        title: 'Morning Standup',
        category: ActivityCategory.work,
        date: baseDate,
        startTime: baseDate.add(const Duration(hours: 9)),
        priority: ActivityPriority.medium,
        status: ActivityStatus.pending,
        reminder: const ReminderSetting(),
        recurrence: const RecurrenceRule(),
        createdAt: baseDate,
        updatedAt: baseDate,
      );

      final act2 = ActivityModel(
        id: 'act-range-2',
        userId: 'user-range-test',
        title: 'Evening Workout',
        category: ActivityCategory.health,
        date: baseDate.add(const Duration(days: 1)),
        startTime: baseDate.add(const Duration(days: 1, hours: 18)),
        priority: ActivityPriority.low,
        status: ActivityStatus.pending,
        reminder: const ReminderSetting(),
        recurrence: const RecurrenceRule(),
        createdAt: baseDate,
        updatedAt: baseDate,
      );

      await db.insertActivities([act1, act2]);

      final userActivities = await db.getActivities('user-range-test');
      expect(userActivities.length, 2);
      expect(userActivities.any((a) => a.title == 'Morning Standup'), isTrue);
      expect(userActivities.any((a) => a.title == 'Evening Workout'), isTrue);
    });

    test('4. Insert, retrieve, and query UserModel in SQLite', () async {
      final user = UserModel(
        id: 'user-sqlite-001',
        name: 'Jordan Smith',
        username: 'jordan_s',
        email: 'jordan@example.com',
        password: 'HashedPassword123',
        college: 'Apex Tech Inc',
        studentId: 'EMP-982',
        bio: 'Lead Engineer',
        avatarSeed: '3',
        remindersEnabled: true,
        dailyDigestEnabled: true,
        soundEnabled: false,
        vibrationEnabled: true,
        createdAt: DateTime(2026, 1, 1),
      );

      await db.insertUser(user);

      final byId = await db.getUserById('user-sqlite-001');
      expect(byId, isNotNull);
      expect(byId!.name, 'Jordan Smith');
      expect(byId.college, 'Apex Tech Inc');

      final byEmail = await db.getUserByEmail('jordan@example.com');
      expect(byEmail, isNotNull);
      expect(byEmail!.username, 'jordan_s');

      final byUsername = await db.getUserByUsername('jordan_s');
      expect(byUsername, isNotNull);
      expect(byUsername!.email, 'jordan@example.com');
    });

    test('5. PDF Import History in SQLite', () async {
      final record = PdfImportRecord(
        id: 'pdf-hist-001',
        userId: 'user-001',
        filename: 'weekly_team_schedule.pdf',
        fileSizeBytes: 20480,
        importDate: DateTime(2026, 10, 1, 10, 0),
        totalDetected: 5,
        importedCount: 5,
        skippedCount: 0,
        status: 'Imported',
        activityTitles: ['Project Sync', 'Design Review', 'Client Demo'],
      );

      await db.insertPdfRecord(record);

      final history = await db.getPdfRecords('user-001');
      expect(history.length, 1);
      expect(history.first.filename, 'weekly_team_schedule.pdf');
      expect(history.first.totalDetected, 5);
      expect(history.first.importedCount, 5);

      await db.deletePdfRecord('pdf-hist-001', 'user-001');
      final emptyHistory = await db.getPdfRecords('user-001');
      expect(emptyHistory.isEmpty, isTrue);
    });

    test('6. Key-Value app settings & getStats in SQLite', () async {
      await db.setSetting('adobe_client_id', 'AdobeTest123456');
      await db.setSetting('theme_mode', 'dark');

      final apiKey = await db.getSetting('adobe_client_id');
      expect(apiKey, 'AdobeTest123456');

      final allSettings = await db.getAllSettings();
      expect(allSettings['theme_mode'], 'dark');

      final stats = await db.getStats();
      expect(stats['settings'], 2);
      expect(stats['activities'], 0);
      expect(stats['users'], 0);
      expect(stats['pdf_imports'], 0);
    });

    test('7. SqliteStorageService synchronous cache and persistence', () async {
      final storage = SqliteStorageService(db);
      await storage.init();

      await storage.setString('test_pref', 'hello_sqlite');
      await storage.setBool('test_flag', true);
      await storage.setInt('test_count', 42);

      expect(storage.getString('test_pref'), 'hello_sqlite');
      expect(storage.getBool('test_flag'), isTrue);
      expect(storage.getInt('test_count'), 42);

      await storage.remove('test_pref');
      expect(storage.getString('test_pref'), isNull);
    });
  });
}
