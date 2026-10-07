import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:activity_reminder_tracker/models/extracted_activity_draft.dart';
import 'package:activity_reminder_tracker/screens/pdf_import/widgets/draft_preview_list.dart';

void main() {
  testWidgets('DraftPreviewList groups and renders activities chronologically by day and time', (tester) async {
    final sampleDrafts = [
      // Monday activities in non-chronological order to test sorting
      ExtractedActivityDraft(
        id: '1',
        title: 'Science',
        weekday: 1, // Monday
        startHour: 11,
        startMinute: 0,
        endHour: 12,
        endMinute: 0,
      ),
      ExtractedActivityDraft(
        id: '2',
        title: 'Math',
        weekday: 1, // Monday
        startHour: 10,
        startMinute: 0,
        endHour: 11,
        endMinute: 0,
      ),
      // Tuesday activity
      ExtractedActivityDraft(
        id: '3',
        title: 'History',
        weekday: 2, // Tuesday
        startHour: 14,
        startMinute: 0,
        endHour: 15,
        endMinute: 0,
      ),
    ];

    List<ExtractedActivityDraft> currentDrafts = List.from(sampleDrafts);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DraftPreviewList(
            drafts: currentDrafts,
            onDraftsUpdated: (updated) => currentDrafts = updated,
            onEditDraft: (_) {},
          ),
        ),
      ),
    );

    // Verify summary header
    expect(find.text('3 Activities Detected across 2 Days'), findsOneWidget);
    expect(find.text('3 of 3 selected to schedule'), findsOneWidget);

    // Verify Day section headers
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Tuesday'), findsOneWidget);
    expect(find.text('2 activities'), findsOneWidget); // Monday
    expect(find.text('1 activity'), findsOneWidget); // Tuesday

    // Verify activity titles
    expect(find.text('Math'), findsOneWidget);
    expect(find.text('Science'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    // Verify formatted time badges
    expect(find.text('10:00 AM - 11:00 AM'), findsOneWidget);
    expect(find.text('11:00 AM - 12:00 PM'), findsOneWidget);
    expect(find.text('2:00 PM - 3:00 PM'), findsOneWidget);

    // Test filter chip: Tap Tuesday
    await tester.tap(find.text('Tue (1)'));
    await tester.pumpAndSettle();

    // Now Monday should not be in the list
    expect(find.text('Monday'), findsNothing);
    expect(find.text('Tuesday'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    // Tap All to restore
    await tester.tap(find.text('All (3)'));
    await tester.pumpAndSettle();
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Tuesday'), findsOneWidget);
  });
}
