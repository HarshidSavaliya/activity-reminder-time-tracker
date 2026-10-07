import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  test('SQLite database can open in-memory and execute queries', () async {
    final db = await openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)');
    await db.insert('test', {'id': 1, 'name': 'Activity Tracker'});
    final result = await db.query('test');
    expect(result.length, equals(1));
    expect(result.first['name'], equals('Activity Tracker'));
    await db.close();
  });
}
