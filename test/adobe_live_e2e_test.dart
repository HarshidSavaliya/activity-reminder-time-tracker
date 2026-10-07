// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:activity_reminder_tracker/core/services/adobe_pdf_service.dart';
import 'package:activity_reminder_tracker/models/pdf_import_instructions.dart';

void main() {
  // Allow real HTTP requests for live integration test
  HttpOverrides.global = null;

  test('Live Adobe Extract API e2e test with user PDF', () async {
    final service = AdobePdfService();

    expect(service.hasCredentials, isTrue);
    expect(service.getClientId(), '0b559d5f4eef460f9b53692462659897');
    expect(service.getClientSecret(), 'p8e-_w3F-a9kInYRUcZAaMzlBkaZdBgKXeuZ');

    final pdfPath = r'C:\Users\Harshid\.gemini\antigravity-ide\brain\76831a0c-715d-4432-b7dd-f5c46a487f0d\.user_uploaded\media_1790828228241.pdf';
    final file = File(pdfPath);
    if (!file.existsSync()) {
      print('Skip: PDF file does not exist locally');
      return;
    }

    final bytes = await file.readAsBytes();
    final drafts = await service.extractActivitiesFromPdf(
      pdfBytes: bytes,
      filename: 'weekly_timetable.pdf',
      instructions: PdfImportInstructions(),
    );

    print('Live Adobe Extraction returned ${drafts.length} activities:');
    final dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    for (int i = 0; i < drafts.length; i++) {
      final d = drafts[i];
      print('${i + 1}. [${dayNames[d.weekday]}] ${d.startHour}:00 - ${d.title}');
    }

    expect(drafts.length, equals(20));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
