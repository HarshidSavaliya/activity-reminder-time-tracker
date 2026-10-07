import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:activity_reminder_tracker/core/services/activity_service.dart';
import 'package:activity_reminder_tracker/core/services/auth_service.dart';
import 'package:activity_reminder_tracker/core/services/notification_service.dart';
import 'package:activity_reminder_tracker/core/services/pdf_history_service.dart';
import 'package:activity_reminder_tracker/core/services/pdf_parser_service.dart';
import 'package:activity_reminder_tracker/models/enums/activity_category.dart';
import 'package:activity_reminder_tracker/models/enums/activity_priority.dart';
import 'package:activity_reminder_tracker/models/extracted_activity_draft.dart';
import 'package:activity_reminder_tracker/models/pdf_import_instructions.dart';
import 'package:activity_reminder_tracker/models/pdf_import_record.dart';
import 'package:activity_reminder_tracker/providers/activity_provider.dart';
import 'package:activity_reminder_tracker/providers/auth_provider.dart';
import 'package:activity_reminder_tracker/providers/theme_provider.dart';
import 'package:activity_reminder_tracker/screens/pdf_import/pdf_import_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Smart PDF Timetable Import Tests', () {
    test('1. Validates and extracts text streams from PDF bytes', () {
      final samplePdfText = '''
%PDF-1.4
Monday
10:00 AM - 11:30 AM Advanced Algorithms Room 204 Prof. Alan Turing
Tuesday
02:00 PM - 05:00 PM Microprocessor Lab Lab 2 Dr. Ada Lovelace
''';
      final bytes = Uint8List.fromList(utf8.encode(samplePdfText));

      final result = PdfTextParser.validateAndExtract(
        bytes: bytes,
        filename: 'College_Schedule.pdf',
      );

      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.extractedText, isNotNull);
    });

    test('2. Rejects invalid files (empty, oversized, wrong extension)', () {
      // Empty file
      final emptyResult = PdfTextParser.validateAndExtract(
        bytes: Uint8List(0),
        filename: 'empty.pdf',
      );
      expect(emptyResult.isValid, isFalse);
      expect(emptyResult.errorMessage, contains('empty'));

      // Non-PDF extension
      final extResult = PdfTextParser.validateAndExtract(
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'timetable.docx',
      );
      expect(extResult.isValid, isFalse);
      expect(extResult.errorMessage, contains('.pdf'));
    });

    test('3. Structured Extraction of Title, Day, Times, Room, and Faculty', () {
      const timetableText = '''
Monday
09:00 AM - 10:30 AM CS401 Data Structures Room 204 Prof. Alan Turing
Wednesday
11:00 AM - 12:30 PM CS404 Database Systems Room 102 Dr. Edgar Codd
''';

      final instructions = PdfImportInstructions(
        readSubjectName: true,
        readDate: true,
        readStartTime: true,
        readEndTime: true,
        readFaculty: true,
        readClassroom: true,
      );

      final drafts = PdfExtractionService.processTimetable(
        rawText: timetableText,
        instructions: instructions,
        existingActivities: [],
      );

      expect(drafts.length, greaterThanOrEqualTo(2));

      final first = drafts.first;
      expect(first.title.toLowerCase(), contains('data structures'));
      expect(first.weekday, equals(1)); // Monday
      expect(first.startHour, equals(9));
      expect(first.startMinute, equals(0));
      expect(first.endHour, equals(10));
      expect(first.endMinute, equals(30));
      expect(first.location, contains('Room 204'));
      expect(first.faculty, contains('Prof. Alan Turing'));
      expect(first.confidence, equals(ExtractionConfidence.high));
    });

    test('4. Custom Natural Language Instruction Filtering (Holidays, Semesters, Labs)', () {
      final instructions = PdfImportInstructions(
        customInstruction: 'Read only Semester 4 Computer Engineering. Ignore holidays. Labs only.',
      );

      final drafts = PdfExtractionService.processTimetable(
        rawText: '',
        templateHint: 'cs_semester_4',
        instructions: instructions,
        existingActivities: [],
      );

      // Verify "Labs only" constraint filtered out pure lectures
      for (final draft in drafts) {
        expect(
          draft.category == ActivityCategory.lab || draft.title.toLowerCase().contains('lab'),
          isTrue,
        );
      }
    });

    test('5. Duplicate Routine Collision Detection', () async {
      final activityService = ActivityService(prefs);
      final notificationService = NotificationService(prefs, enableTimer: false);
      final activityCtrl = ActivityController(activityService, notificationService);

      const userId = 'user_123';
      final now = DateTime.now();

      // Pre-schedule an existing activity on Monday at 09:00 AM
      final existingMonday = now.add(Duration(days: (1 - now.weekday) % 7));
      await activityCtrl.createActivity(
        userId: userId,
        title: 'Data Structures & Algorithms',
        category: ActivityCategory.lecture,
        date: existingMonday,
        startTime: DateTime(existingMonday.year, existingMonday.month, existingMonday.day, 9, 0),
        endTime: DateTime(existingMonday.year, existingMonday.month, existingMonday.day, 10, 30),
        priority: ActivityPriority.high,
        location: 'Room 204',
      );

      final instructions = PdfImportInstructions();
      final drafts = PdfExtractionService.processTimetable(
        rawText: '',
        templateHint: 'cs_semester_4',
        instructions: instructions,
        existingActivities: activityCtrl.activities,
      );

      final duplicate = drafts.firstWhere((d) => d.title.contains('Data Structures'));
      expect(duplicate.isDuplicate, isTrue);
      expect(duplicate.duplicateReason, isNotNull);
      expect(duplicate.duplicateReason, contains('Already exists in your routine'));
      expect(duplicate.isSelected, isFalse); // Deselected by default to protect routine
    });

    test('6. PDF Import History Persistence & User Isolation', () async {
      final historyService = PdfHistoryService(prefs);

      final recordA = PdfImportRecord(
        id: 'rec_1',
        userId: 'user_A',
        filename: 'CS_Semester_4.pdf',
        fileSizeBytes: 142000,
        importDate: DateTime.now(),
        totalDetected: 8,
        importedCount: 7,
        skippedCount: 1,
        status: 'Imported',
        activityTitles: ['Data Structures', 'Microprocessors'],
      );

      await historyService.saveRecord(recordA);

      final userARecords = historyService.getRecords('user_A');
      expect(userARecords.length, equals(1));
      expect(userARecords.first.filename, equals('CS_Semester_4.pdf'));
      expect(userARecords.first.importedCount, equals(7));

      // User isolation: User B must have no records
      final userBRecords = historyService.getRecords('user_B');
      expect(userBRecords, isEmpty);
    });

    testWidgets('7. Wizard flow navigates Upload -> Instructions -> Processing -> Review',
        (tester) async {
      final authService = AuthService(prefs);
      final notificationService = NotificationService(prefs, enableTimer: false);
      final activityService = ActivityService(prefs);

      final authCtrl = AuthController(authService);
      final activityCtrl = ActivityController(activityService, notificationService);
      final themeCtrl = ThemeController(prefs);

      await authCtrl.register(
        name: 'Sarah Connor',
        username: 'sconnor',
        email: 'sarah@college.edu',
        password: 'Password123',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authCtrl),
            ChangeNotifierProvider.value(value: activityCtrl),
            ChangeNotifierProvider.value(value: themeCtrl),
          ],
          child: const MaterialApp(
            home: PdfImportScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step 1: Upload
      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.text('Upload PDF Timetable'), findsOneWidget);

      // Tap sample template chip
      await tester.ensureVisible(find.text('Semester 4 Computer Engineering'));
      await tester.tap(find.text('Semester 4 Computer Engineering'));
      await tester.pumpAndSettle();

      // Scroll and tap Proceed to Step 2: Instructions
      final continueBtn = find.text('Continue to Instructions →');
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 5'), findsOneWidget);
      expect(find.text('What information should we read from this PDF?'), findsOneWidget);
      expect(find.text('Subject Name'), findsOneWidget);
      expect(find.text('Start Time'), findsOneWidget);

      // Scroll and tap Proceed to Step 3 & 4
      final extractBtn = find.text('Extract Activities →');
      await tester.ensureVisible(extractBtn);
      await tester.tap(extractBtn);
      await tester.pump(); // Triggers Step 3: Processing

      expect(find.text('Step 3 of 5'), findsOneWidget);

      // Wait for async processing pipeline to settle into Step 4
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Step 4: Review
      expect(find.text('Step 4 of 5'), findsOneWidget);
      expect(find.textContaining('Activities Detected'), findsOneWidget);
      expect(find.text('Select All'), findsOneWidget);
      expect(find.text('Deselect All'), findsOneWidget);
    });

    test('8. Guaranteed NO dummy data when uploaded PDF cannot be read or contains no schedule', () async {
      // Create a valid PDF format document with no timetable content (e.g. an essay or report)
      final nonSchedulePdf = '''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /Contents 4 0 R >>
endobj
4 0 obj
<< /Length 55 >>
stream
BT
/F1 12 Tf
100 700 Td
(This is an essay about architecture with no timetable.) Tj
ET
endstream
endobj
xref
trailer
<< /Root 1 0 R >>
%%EOF
''';

      final bytes = Uint8List.fromList(utf8.encode(nonSchedulePdf));
      final parser = PdfParserService();

      final drafts = await parser.parseTimetable(
        pdfBytes: bytes,
        filename: 'Architecture_Essay.pdf',
      );

      // CRITICAL REQUIREMENT: Must return empty list, absolutely NO dummy data!
      expect(drafts, isEmpty);

      // Also verify processTimetable with no templateHint returns empty list (no dummy fallback)
      final rawDrafts = PdfParserService.processTimetable(
        rawText: 'Just some general plain text without days or hours.',
        templateHint: null,
      );
      expect(rawDrafts, isEmpty);
    });
  });
}
