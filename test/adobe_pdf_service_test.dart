import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:activity_reminder_tracker/core/services/adobe_pdf_service.dart';
import 'package:activity_reminder_tracker/core/services/shared_preferences_storage_service.dart';
import 'package:activity_reminder_tracker/models/enums/activity_category.dart';
import 'package:activity_reminder_tracker/models/extracted_activity_draft.dart';
import 'package:activity_reminder_tracker/models/pdf_import_instructions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late SharedPreferencesStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = SharedPreferencesStorageService(prefs);
  });

  group('AdobePdfService Unit Tests', () {
    test('1. Saves, retrieves, and clears Adobe credentials in storage', () async {
      final service = AdobePdfService(
        storage: storage,
        defaultClientId: null,
        defaultClientSecret: null,
      );

      expect(service.hasCredentials, isFalse);
      expect(service.getClientId(), isNull);
      expect(service.getClientSecret(), isNull);

      await service.saveCredentials(
        clientId: 'adobe_client_id_12345',
        clientSecret: 'adobe_client_secret_67890',
        embedApiKey: 'adobe_embed_key_abcde',
      );

      expect(service.hasCredentials, isTrue);
      expect(service.getClientId(), 'adobe_client_id_12345');
      expect(service.getClientSecret(), 'adobe_client_secret_67890');
      expect(service.getEmbedApiKey(), 'adobe_embed_key_abcde');

      await service.clearCredentials();
      expect(service.hasCredentials, isFalse);
      expect(service.getClientId(), isNull);
      expect(service.getClientSecret(), isNull);
    });

    test('2. Throws AdobeApiException when credentials are missing', () async {
      final service = AdobePdfService(
        storage: storage,
        defaultClientId: null,
        defaultClientSecret: null,
      );
      final dummyPdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);

      expect(
        () => service.extractActivitiesFromPdf(
          pdfBytes: dummyPdf,
          filename: 'timetable.pdf',
        ),
        throwsA(isA<AdobeApiException>()),
      );
    });

    test('3. Uses pre-configured default Adobe credentials when not explicitly in storage', () {
      final service = AdobePdfService(storage: storage);
      expect(service.hasCredentials, isTrue);
      expect(service.getClientId(), '0b559d5f4eef460f9b53692462659897');
      expect(service.getClientSecret(), 'p8e-_w3F-a9kInYRUcZAaMzlBkaZdBgKXeuZ');
      expect(service.getEmbedApiKey(), '0b559d5f4eef460f9b53692462659897');
    });

    test('4. Accurately parses Adobe structuredData.json table elements into activities', () {
      final service = AdobePdfService(storage: storage);

      final adobeJson = {
        'elements': [
          {
            'Path': '//Document/Table[1]/TR[1]/TH[1]',
            'Text': 'Monday',
            'Bounds': [50.0, 700.0, 150.0, 720.0],
            'Page': 0,
          },
          {
            'Path': '//Document/Table[1]/TR[2]/TD[1]',
            'Text': '09:00 AM - 10:30 AM CS301 Systems Programming Room 304 Prof. Dennis Ritchie',
            'Bounds': [50.0, 650.0, 450.0, 680.0],
            'Page': 0,
          },
          {
            'Path': '//Document/Table[1]/TR[3]/TD[1]',
            'Text': '02:00 PM - 04:00 PM CS302 Hardware Lab Room 102 Dr. John Hennessy',
            'Bounds': [50.0, 600.0, 450.0, 630.0],
            'Page': 0,
          },
        ],
      };

      final drafts = service.parseAdobeStructuredJson(
        data: adobeJson,
        instructions: PdfImportInstructions(),
      );

      expect(drafts.length, equals(2));

      final first = drafts.first;
      expect(first.title.toLowerCase(), contains('systems programming'));
      expect(first.weekday, equals(1)); // Monday
      expect(first.startHour, equals(9));
      expect(first.startMinute, equals(0));
      expect(first.endHour, equals(10));
      expect(first.endMinute, equals(30));
      expect(first.location, contains('Room 304'));
      expect(first.faculty, contains('Prof. Dennis Ritchie'));
      expect(first.confidence, equals(ExtractionConfidence.high));

      final second = drafts[1];
      expect(second.title.toLowerCase(), contains('hardware lab'));
      expect(second.category, equals(ActivityCategory.lab));
      expect(second.startHour, equals(14));
      expect(second.startMinute, equals(0));
    });

    test('5. Accurately extracts all 20 weekly activities from user PDF 2D timetable matrix', () {
      final service = AdobePdfService(storage: storage);

      // Structure directly matching Adobe Extract API output on the user's uploaded timetable PDF
      final userPdfAdobeJson = {
        'elements': [
          // Row 1: Headers (Col 1 to 7)
          {'Path': '//Document/Sect/Table/TR/TH[2]/P', 'Text': 'Tuesday '},
          {'Path': '//Document/Sect/Table/TR/TH[3]/P', 'Text': 'Wednesday '},
          {'Path': '//Document/Sect/Table/TR/TH[4]/P', 'Text': 'Thursday '},
          {'Path': '//Document/Sect/Table/TR/TH[5]/P', 'Text': 'Friday '},
          {'Path': '//Document/Sect/Table/TR/TH[6]/P[2]', 'Text': 'Saturday '},
          {'Path': '//Document/Sect/Table/TR/TH[7]/P', 'Text': 'Sunday '},

          // Row 2: 10:00am slots
          {'Path': '//Document/Sect/Table/TR[2]/TD/P', 'Text': '10:00am '},
          {'Path': '//Document/Sect/Table/TR[2]/TD/P[2]', 'Text': 'Math '},
          {'Path': '//Document/Sect/Table/TR[2]/TD[3]/P', 'Text': '10:00am '},
          {'Path': '//Document/Sect/Table/TR[2]/TD[3]/P[2]', 'Text': 'Science '},
          {'Path': '//Document/Sect/Table/TR[2]/TD[5]/P', 'Text': '10:00am '},
          {'Path': '//Document/Sect/Table/TR[2]/TD[5]/P[2]', 'Text': 'Math '},
          {'Path': '//Document/Sect/Table/TR[2]/TD[6]/P', 'Text': '10:00am '},
          {'Path': '//Document/Sect/Table/TR[2]/TD[6]/P[2]', 'Text': 'Science '},
          {'Path': '//Document/Sect/Table/TR[2]/TD[7]/P', 'Text': '10:00am Math '},

          // Row 3: 11:00am slots
          {'Path': '//Document/Sect/Table/TR[3]/TD/P', 'Text': '11:00am '},
          {'Path': '//Document/Sect/Table/TR[3]/TD/P[2]', 'Text': 'Science '},
          {'Path': '//Document/Sect/Table/TR[3]/TD[2]/P', 'Text': '11:00am '},
          {'Path': '//Document/Sect/Table/TR[3]/TD[2]/P[2]', 'Text': 'History '},
          {'Path': '//Document/Sect/Table/TR[3]/TD[5]/P', 'Text': '11:00am '},
          {'Path': '//Document/Sect/Table/TR[3]/TD[5]/P[2]', 'Text': 'Science '},
          {'Path': '//Document/Sect/Table/TR[3]/TD[6]/P', 'Text': '11:00am '},
          {'Path': '//Document/Sect/Table/TR[3]/TD[6]/P[2]', 'Text': 'Math '},

          // Row 4: 1:00pm slots
          {'Path': '//Document/Sect/Table/TR[4]/TD/P', 'Text': '1:00pm '},
          {'Path': '//Document/Sect/Table/TR[4]/TD/P[2]', 'Text': 'History '},
          {'Path': '//Document/Sect/Table/TR[4]/TD[2]/P', 'Text': '1:00pm '},
          {'Path': '//Document/Sect/Table/TR[4]/TD[2]/P[2]', 'Text': 'Math '},
          {'Path': '//Document/Sect/Table/TR[4]/TD[4]/P', 'Text': '1:00pm '},
          {'Path': '//Document/Sect/Table/TR[4]/TD[4]/P[2]', 'Text': 'Science '},

          // Row 5: 2:00pm slots
          {'Path': '//Document/Sect/Table/TR[5]/TD[3]/P', 'Text': '2:00pm '},
          {'Path': '//Document/Sect/Table/TR[5]/TD[3]/P[2]', 'Text': 'Math '},
          {'Path': '//Document/Sect/Table/TR[5]/TD[5]/P/Sub', 'Text': '2:00pm '},
          {'Path': '//Document/Sect/Table/TR[5]/TD[5]/P/Sub[2]', 'Text': 'History '},

          // Row 6: 3:00pm slots
          {'Path': '//Document/Sect/Table/TR[6]/TD[2]/P', 'Text': '3:00pm '},
          {'Path': '//Document/Sect/Table/TR[6]/TD[2]/P[2]', 'Text': 'Math '},
          {'Path': '//Document/Sect/Table/TR[6]/TD[4]/P', 'Text': '3:00pm '},
          {'Path': '//Document/Sect/Table/TR[6]/TD[4]/P[2]', 'Text': 'Math '},

          // Row 7: 4:00pm slots
          {'Path': '//Document/Sect/Table/TR[7]/TD/P', 'Text': '4:00pm '},
          {'Path': '//Document/Sect/Table/TR[7]/TD/P[2]', 'Text': 'History '},
          {'Path': '//Document/Sect/Table/TR[7]/TD[5]/P/Sub', 'Text': '4:00pm '},
          {'Path': '//Document/Sect/Table/TR[7]/TD[5]/P/Sub[2]', 'Text': 'History '},

          // Row 8: 5:00pm slots
          {'Path': '//Document/Sect/Table/TR[8]/TD[2]/P', 'Text': '5:00pm '},
          {'Path': '//Document/Sect/Table/TR[8]/TD[2]/P[2]', 'Text': 'Science '},
          {'Path': '//Document/Sect/Table/TR[8]/TD[3]/P', 'Text': '5:00pm '},
          {'Path': '//Document/Sect/Table/TR[8]/TD[3]/P[2]', 'Text': 'History '},
        ],
      };

      final drafts = service.parseAdobeStructuredJson(
        data: userPdfAdobeJson,
        instructions: PdfImportInstructions(),
      );

      // Verify exactly 20 activities extracted
      expect(drafts.length, equals(20));

      // Group activities by weekday
      final monday = drafts.where((d) => d.weekday == 1).toList();
      final tuesday = drafts.where((d) => d.weekday == 2).toList();
      final wednesday = drafts.where((d) => d.weekday == 3).toList();
      final thursday = drafts.where((d) => d.weekday == 4).toList();
      final friday = drafts.where((d) => d.weekday == 5).toList();
      final saturday = drafts.where((d) => d.weekday == 6).toList();
      final sunday = drafts.where((d) => d.weekday == 7).toList();

      // Monday: 10am Math, 11am Science, 1pm History, 4pm History
      expect(monday.length, equals(4));
      expect(monday[0].title, equals('Math'));
      expect(monday[0].startHour, equals(10));
      expect(monday[1].title, equals('Science'));
      expect(monday[1].startHour, equals(11));
      expect(monday[2].title, equals('History'));
      expect(monday[2].startHour, equals(13));
      expect(monday[3].title, equals('History'));
      expect(monday[3].startHour, equals(16));

      // Tuesday: 11am History, 1pm Math, 3pm Math, 5pm Science
      expect(tuesday.length, equals(4));
      expect(tuesday[0].title, equals('History'));
      expect(tuesday[0].startHour, equals(11));
      expect(tuesday[1].title, equals('Math'));
      expect(tuesday[1].startHour, equals(13));
      expect(tuesday[2].title, equals('Math'));
      expect(tuesday[2].startHour, equals(15));
      expect(tuesday[3].title, equals('Science'));
      expect(tuesday[3].startHour, equals(17));

      // Wednesday: 10am Science, 2pm Math, 5pm History
      expect(wednesday.length, equals(3));
      expect(wednesday[0].title, equals('Science'));
      expect(wednesday[0].startHour, equals(10));
      expect(wednesday[1].title, equals('Math'));
      expect(wednesday[1].startHour, equals(14));
      expect(wednesday[2].title, equals('History'));
      expect(wednesday[2].startHour, equals(17));

      // Thursday: 1pm Science, 3pm Math
      expect(thursday.length, equals(2));
      expect(thursday[0].title, equals('Science'));
      expect(thursday[0].startHour, equals(13));
      expect(thursday[1].title, equals('Math'));
      expect(thursday[1].startHour, equals(15));

      // Friday: 10am Math, 11am Science, 2pm History, 4pm History
      expect(friday.length, equals(4));
      expect(friday[0].title, equals('Math'));
      expect(friday[0].startHour, equals(10));
      expect(friday[1].title, equals('Science'));
      expect(friday[1].startHour, equals(11));
      expect(friday[2].title, equals('History'));
      expect(friday[2].startHour, equals(14));
      expect(friday[3].title, equals('History'));
      expect(friday[3].startHour, equals(16));

      // Saturday: 10am Science, 11am Math
      expect(saturday.length, equals(2));
      expect(saturday[0].title, equals('Science'));
      expect(saturday[0].startHour, equals(10));
      expect(saturday[1].title, equals('Math'));
      expect(saturday[1].startHour, equals(11));

      // Sunday: 10am Math
      expect(sunday.length, equals(1));
      expect(sunday[0].title, equals('Math'));
      expect(sunday[0].startHour, equals(10));
    });

    test('6. NEVER gives dummy data when Adobe JSON has no timetable content', () {
      final service = AdobePdfService(storage: storage);

      // JSON representing a non-timetable PDF (e.g. an essay, receipt, or blank document)
      final emptyAdobeJson = {
        'elements': [
          {
            'Path': '//Document/P[1]',
            'Text': 'This is an introductory essay with no schedule or timetable information.',
            'Bounds': [50.0, 700.0, 400.0, 720.0],
            'Page': 0,
          },
        ],
      };

      final drafts = service.parseAdobeStructuredJson(
        data: emptyAdobeJson,
        instructions: PdfImportInstructions(),
      );

      // CRITICAL REQUIREMENT: Must return empty list, absolutely NO dummy data!
      expect(drafts, isEmpty);
    });
  });
}
