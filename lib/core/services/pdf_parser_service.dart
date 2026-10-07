import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:uuid/uuid.dart';

import 'adobe_pdf_service.dart';

import '../../models/activity_model.dart';
import '../../models/enums/activity_category.dart';
import '../../models/enums/activity_priority.dart';
import '../../models/extracted_activity_draft.dart';
import '../../models/pdf_import_instructions.dart';
import '../../models/recurrence_rule.dart';

/// Represents a positioned chunk of text in PDF 2D coordinate space.
class SpatialTextChunk {
  final String text;
  final double x;
  final double y;
  final double width;
  final double height;
  final int pageIndex;

  const SpatialTextChunk({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.pageIndex = 0,
  });

  double get right => x + width;
  double get bottom => y + height;

  @override
  String toString() => 'SpatialTextChunk("$text", x: $x, y: $y, w: $width, h: $height)';
}

/// Result of PDF document validation and coordinate-aware extraction.
class PdfValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? extractedText;
  final List<SpatialTextChunk> spatialChunks;
  final bool isScanned;
  final int estimatedPageCount;

  const PdfValidationResult({
    required this.isValid,
    this.errorMessage,
    this.extractedText,
    this.spatialChunks = const [],
    this.isScanned = false,
    this.estimatedPageCount = 1,
  });
}

/// Abstract contract for timetable extraction pipelines.
abstract class TimetableParser {
  Future<List<ExtractedActivityDraft>> parseTimetable({
    required Uint8List pdfBytes,
    required String filename,
    PdfImportInstructions? instructions,
    List<ActivityModel> existingActivities = const [],
    String? explicitAdobeClientId,
    String? explicitAdobeClientSecret,
  });
}

/// Core spatial PDF parsing service implementing coordinate-aware text and grid parsing,
/// Adobe Acrobat Services Sensei AI table extraction, and local FlateDecode decompression
/// for activity schedules.
class PdfParserService implements TimetableParser {
  static const _uuid = Uuid();
  static const int maxFileSizeBytes = 20 * 1024 * 1024; // 20 MB

  final AdobePdfService? adobeService;

  PdfParserService({
    this.adobeService,
  });

  @override
  Future<List<ExtractedActivityDraft>> parseTimetable({
    required Uint8List pdfBytes,
    required String filename,
    PdfImportInstructions? instructions,
    List<ActivityModel> existingActivities = const [],
    String? explicitAdobeClientId,
    String? explicitAdobeClientSecret,
  }) async {
    final effectiveInstructions = instructions ?? PdfImportInstructions();

    // 0. Primary AI Engine: Adobe Acrobat Services (PDF Extract API) if credentials available
    final adobe = adobeService;
    if (adobe != null &&
        (adobe.hasCredentials ||
            (explicitAdobeClientId != null && explicitAdobeClientSecret != null))) {
      try {
        final adobeDrafts = await adobe.extractActivitiesFromPdf(
          pdfBytes: pdfBytes,
          filename: filename,
          instructions: effectiveInstructions,
          explicitClientId: explicitAdobeClientId,
          explicitClientSecret: explicitAdobeClientSecret,
        );

        if (adobeDrafts.isNotEmpty) {
          final filtered = applyUserInstructions(
            drafts: adobeDrafts,
            instructions: effectiveInstructions,
          );
          detectDuplicates(
            drafts: filtered,
            existingActivities: existingActivities,
          );
          _sortDrafts(filtered);
          return filtered;
        }
      } catch (e) {
        // Fall back gracefully to local parser if network or credentials issue
      }
    }

    final validation = validateAndExtract(bytes: pdfBytes, filename: filename);

    if (!validation.isValid) {
      throw Exception(validation.errorMessage ?? 'Invalid PDF schedule document.');
    }

    List<ExtractedActivityDraft> rawDrafts = [];

    // 1. Coordinate-Aware 2D matrix reconstruction
    if (validation.spatialChunks.isNotEmpty) {
      rawDrafts = extractSpatialMatrix(
        chunks: validation.spatialChunks,
        instructions: effectiveInstructions,
      );
    }

    // 2. Linear text stream extraction fallback if 2D matrix found < 2 entries
    if (rawDrafts.length < 2 &&
        validation.extractedText != null &&
        validation.extractedText!.trim().isNotEmpty) {
      final lineDrafts = parseLines(validation.extractedText!, effectiveInstructions);
      if (lineDrafts.isNotEmpty) {
        rawDrafts = lineDrafts;
      }
    }

    // CRITICAL REQUIREMENT: NEVER inject dummy data when PDF is not read!
    // If the PDF document contains no timetable or could not be read,
    // rawDrafts remains empty rather than fabricating fake classes or activities.

    // 3. Natural language custom user instructions
    final filtered = applyUserInstructions(
      drafts: rawDrafts,
      instructions: effectiveInstructions,
    );

    // 4. Cross-reference duplicates
    detectDuplicates(
      drafts: filtered,
      existingActivities: existingActivities,
    );

    _sortDrafts(filtered);
    return filtered;
  }

  static void _sortDrafts(List<ExtractedActivityDraft> list) {
    list.sort((a, b) {
      if (a.weekday != b.weekday) return a.weekday.compareTo(b.weekday);
      if (a.startHour != b.startHour) return a.startHour.compareTo(b.startHour);
      return a.startMinute.compareTo(b.startMinute);
    });
  }

  /// Public static pipeline entry for processing raw text or sample timetables.
  static List<ExtractedActivityDraft> processTimetable({
    required String rawText,
    PdfImportInstructions? instructions,
    List<ActivityModel> existingActivities = const [],
    String? templateHint,
    bool isScanned = false,
  }) {
    final effectiveInstructions = instructions ?? PdfImportInstructions();
    List<ExtractedActivityDraft> rawDrafts = [];

    if (rawText.trim().isNotEmpty) {
      final spatialChunks = _synthesizeSpatialChunksFromText(rawText);
      rawDrafts = extractSpatialMatrix(chunks: spatialChunks, instructions: effectiveInstructions);
      if (rawDrafts.length < 2) {
        final lineDrafts = parseLines(rawText, effectiveInstructions);
        if (lineDrafts.isNotEmpty) rawDrafts = lineDrafts;
      }
    }

    // Demo sample templates are ONLY loaded if explicitly requested by templateHint
    if (rawDrafts.isEmpty && templateHint != null && templateHint.isNotEmpty) {
      rawDrafts = _generateSampleTemplateDrafts(
        instructions: effectiveInstructions,
        templateHint: templateHint,
      );
    }

    final filtered = applyUserInstructions(drafts: rawDrafts, instructions: effectiveInstructions);
    detectDuplicates(drafts: filtered, existingActivities: existingActivities);
    _sortDrafts(filtered);
    return filtered;
  }

  /// Validates the uploaded file bytes and extracts spatial text chunks.
  static PdfValidationResult validateAndExtract({
    required Uint8List bytes,
    required String filename,
  }) {
    if (bytes.isEmpty) {
      return const PdfValidationResult(
        isValid: false,
        errorMessage: 'The selected file is empty (0 bytes). Please select a valid PDF timetable.',
      );
    }

    if (bytes.length > maxFileSizeBytes) {
      final sizeMb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      return PdfValidationResult(
        isValid: false,
        errorMessage: 'File size ($sizeMb MB) exceeds the maximum allowed limit of 20 MB.',
      );
    }

    if (!filename.toLowerCase().endsWith('.pdf')) {
      return const PdfValidationResult(
        isValid: false,
        errorMessage: 'Unsupported file format. Please upload a document with a .pdf extension.',
      );
    }

    // Inspect PDF Magic Header (%PDF-)
    final headerStr = String.fromCharCodes(bytes.take(16));
    final isPdfHeader = headerStr.contains('%PDF-');

    // Handle plain text test payloads or mock PDF content gracefully
    if (!isPdfHeader) {
      final rawText = utf8.decode(bytes, allowMalformed: true);
      if (_hasTimetableKeywords(rawText)) {
        final chunks = _synthesizeSpatialChunksFromText(rawText);
        return PdfValidationResult(
          isValid: true,
          extractedText: rawText,
          spatialChunks: chunks,
          isScanned: false,
          estimatedPageCount: 1,
        );
      }

      return const PdfValidationResult(
        isValid: false,
        errorMessage: 'The selected file does not appear to be a valid or intact PDF document.',
      );
    }

    // Binary PDF stream extraction with spatial matrix tracking
    final content = latin1.decode(bytes);
    final pageMatches = RegExp(r'/Type\s*/Page\b').allMatches(content);
    final pageCount = pageMatches.isNotEmpty ? pageMatches.length : 1;

    final spatialChunks = <SpatialTextChunk>[];
    final textBuffer = StringBuffer();

    _extractStreamsAndSpatialOperators(bytes, content, spatialChunks, textBuffer);

    final extracted = textBuffer.toString().trim();

    // Scanned document detection: < 20 characters per page or presence of Image XObjects
    bool isScanned = false;
    final avgCharsPerPage = pageCount > 0 ? extracted.length / pageCount : extracted.length;
    if (avgCharsPerPage < 20) {
      if (content.contains('/Subtype /Image') ||
          content.contains('/Image') ||
          content.contains('/XObject')) {
        isScanned = true;
      }
    }

    // If stream parsing extracted very little because of PDF FlateDecode compression,
    // synthesize spatial chunks from any recoverable text blocks
    if (spatialChunks.isEmpty && extracted.isNotEmpty) {
      spatialChunks.addAll(_synthesizeSpatialChunksFromText(extracted));
    }

    return PdfValidationResult(
      isValid: true,
      extractedText: extracted,
      spatialChunks: spatialChunks,
      isScanned: isScanned,
      estimatedPageCount: pageCount,
    );
  }

  static bool _hasTimetableKeywords(String text) {
    return text.contains('Monday') ||
        text.contains('Tuesday') ||
        text.contains('Wednesday') ||
        text.contains('Thursday') ||
        text.contains('Friday') ||
        text.contains('Timetable') ||
        text.contains('Schedule') ||
        text.contains('Lecture') ||
        text.contains('AM') ||
        text.contains('PM');
  }

  static void _extractStreamsAndSpatialOperators(
    Uint8List bytes,
    String content,
    List<SpatialTextChunk> chunks,
    StringBuffer textBuffer,
  ) {
    // 1. Process uncompressed text stream operators
    _extractSpatialOperators(content, chunks, textBuffer);

    // 2. Locate and decompress FlateDecode (zlib) streams in the PDF binary
    try {
      final streamRanges = _findStreamRanges(bytes);
      for (final range in streamRanges) {
        try {
          final streamBytes = bytes.sublist(range.start, range.end);
          List<int>? decompressed;
          try {
            decompressed = ZLibDecoder().decodeBytes(streamBytes, verify: false);
          } catch (_) {
            // Not zlib compressed, or damaged stream
          }

          if (decompressed != null && decompressed.isNotEmpty) {
            final streamStr = latin1.decode(decompressed);
            _extractSpatialOperators(streamStr, chunks, textBuffer);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  static List<_ByteRange> _findStreamRanges(Uint8List bytes) {
    final ranges = <_ByteRange>[];
    final len = bytes.length;
    int i = 0;
    while (i < len - 10) {
      if (bytes[i] == 115 && // s
          bytes[i + 1] == 116 && // t
          bytes[i + 2] == 114 && // r
          bytes[i + 3] == 101 && // e
          bytes[i + 4] == 97 && // a
          bytes[i + 5] == 109) { // m
        int start = i + 6;
        if (start < len && bytes[start] == 13) start++; // \r
        if (start < len && bytes[start] == 10) start++; // \n

        int end = -1;
        for (int j = start; j < len - 9; j++) {
          if (bytes[j] == 101 && // e
              bytes[j + 1] == 110 && // n
              bytes[j + 2] == 100 && // d
              bytes[j + 3] == 115 && // s
              bytes[j + 4] == 116 && // t
              bytes[j + 5] == 114 && // r
              bytes[j + 6] == 101 && // e
              bytes[j + 7] == 97 && // a
              bytes[j + 8] == 109) { // m
            end = j;
            break;
          }
        }

        if (end != -1 && end > start) {
          int trimmedEnd = end;
          if (trimmedEnd > start && bytes[trimmedEnd - 1] == 10) trimmedEnd--;
          if (trimmedEnd > start && bytes[trimmedEnd - 1] == 13) trimmedEnd--;
          ranges.add(_ByteRange(start, trimmedEnd));
          i = end + 9;
          continue;
        }
      }
      i++;
    }
    return ranges;
  }

  static void _extractSpatialOperators(
    String content,
    List<SpatialTextChunk> chunks,
    StringBuffer textBuffer,
  ) {
    double currentX = 0;
    double currentY = 0;
    double currentFontSize = 12.0;

    final operatorRegex = RegExp(
      r'(\[.*?\]\s*TJ|\(.*?\)\s*Tj|[+-]?\d*\.?\d+\s+[+-]?\d*\.?\d+\s+[+-]?\d*\.?\d+\s+[+-]?\d*\.?\d+\s+[+-]?\d*\.?\d+\s+[+-]?\d*\.?\d+\s+Tm|[+-]?\d*\.?\d+\s+[+-]?\d*\.?\d+\s+Td|[+-]?\d*\.?\d+\s+[+-]?\d*\.?\d+\s+TD|/F\d+\s+[+-]?\d*\.?\d+\s+Tf)',
    );

    for (final match in operatorRegex.allMatches(content)) {
      final token = match.group(0)?.trim();
      if (token == null || token.isEmpty) continue;

      if (token.endsWith('Tm')) {
        final parts = token.split(RegExp(r'\s+'));
        if (parts.length >= 7) {
          currentX = double.tryParse(parts[4]) ?? currentX;
          currentY = double.tryParse(parts[5]) ?? currentY;
        }
      } else if (token.endsWith('Td') || token.endsWith('TD')) {
        final parts = token.split(RegExp(r'\s+'));
        if (parts.length >= 3) {
          final dx = double.tryParse(parts[0]) ?? 0;
          final dy = double.tryParse(parts[1]) ?? 0;
          currentX += dx;
          currentY += dy;
        }
      } else if (token.endsWith('Tf')) {
        final parts = token.split(RegExp(r'\s+'));
        if (parts.length >= 3) {
          currentFontSize = double.tryParse(parts[1]) ?? currentFontSize;
        }
      } else if (token.endsWith('Tj')) {
        final strMatch = RegExp(r'\((.*?)\)\s*Tj').firstMatch(token);
        if (strMatch != null) {
          final raw = strMatch.group(1);
          if (raw != null && raw.trim().isNotEmpty) {
            final unescaped = _unescapePdfString(raw);
            final width = unescaped.length * (currentFontSize * 0.55);
            chunks.add(SpatialTextChunk(
              text: unescaped,
              x: currentX,
              y: currentY,
              width: width,
              height: currentFontSize,
            ));
            textBuffer.writeln(unescaped);
            currentX += width;
          }
        }
      } else if (token.endsWith('TJ')) {
        final arrayMatch = RegExp(r'\[(.*?)\]\s*TJ').firstMatch(token);
        if (arrayMatch != null) {
          final inner = arrayMatch.group(1);
          if (inner != null) {
            final subMatches = RegExp(r'\((.*?)\)').allMatches(inner);
            final line = subMatches.map((m) => _unescapePdfString(m.group(1) ?? '')).join(' ');
            if (line.trim().isNotEmpty) {
              final width = line.length * (currentFontSize * 0.55);
              chunks.add(SpatialTextChunk(
                text: line,
                x: currentX,
                y: currentY,
                width: width,
                height: currentFontSize,
              ));
              textBuffer.writeln(line);
              currentX += width;
            }
          }
        }
      }
    }
  }

  static List<SpatialTextChunk> _synthesizeSpatialChunksFromText(String text) {
    final chunks = <SpatialTextChunk>[];
    final lines = text.split(RegExp(r'\r?\n'));
    double y = 50.0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        y += 18.0;
        continue;
      }

      final segments = trimmed.split(RegExp(r'\s{2,}|\t'));
      double x = 40.0;
      for (final segment in segments) {
        final str = segment.trim();
        if (str.isNotEmpty) {
          final width = str.length * 7.5;
          chunks.add(SpatialTextChunk(
            text: str,
            x: x,
            y: y,
            width: width,
            height: 14.0,
          ));
          x += width + 20.0;
        }
      }
      y += 24.0;
    }

    return chunks;
  }

  static String _unescapePdfString(String input) {
    return input
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\r', '\n')
        .replaceAll(r'\n', ' ')
        .replaceAll(r'\t', ' ')
        .trim();
  }

  /// Reconstructs 2D tabular matrix from spatial bounding boxes (x, y, width, height).
  /// Forms horizontal rows by grouping items with matching or close y-coordinates;
  /// identifies day columns by clustering x-coordinates.
  static List<ExtractedActivityDraft> extractSpatialMatrix({
    required List<SpatialTextChunk> chunks,
    required PdfImportInstructions instructions,
  }) {
    if (chunks.isEmpty) return [];

    // Sort by Y to group into horizontal rows
    final sortedByY = List<SpatialTextChunk>.from(chunks)
      ..sort((a, b) => a.y.compareTo(b.y));

    final rows = <List<SpatialTextChunk>>[];
    List<SpatialTextChunk> currentRow = [];
    double? currentRowY;

    for (final chunk in sortedByY) {
      if (currentRowY == null || (chunk.y - currentRowY).abs() <= 14.0) {
        currentRow.add(chunk);
        currentRowY = (currentRowY == null) ? chunk.y : (currentRowY + chunk.y) / 2;
      } else {
        currentRow.sort((a, b) => a.x.compareTo(b.x));
        rows.add(currentRow);
        currentRow = [chunk];
        currentRowY = chunk.y;
      }
    }
    if (currentRow.isNotEmpty) {
      currentRow.sort((a, b) => a.x.compareTo(b.x));
      rows.add(currentRow);
    }

    // 1. Detect Day Header Columns by clustering x-coordinates of day labels
    final dayColumns = <_DayColumn>[];
    for (final row in rows) {
      for (final chunk in row) {
        final weekday = _detectWeekday(chunk.text);
        if (weekday != null) {
          dayColumns.add(_DayColumn(
            weekday: weekday,
            startX: chunk.x - 15.0,
            endX: chunk.right + 35.0,
            headerText: chunk.text,
          ));
        }
      }
      if (dayColumns.length >= 2) break; // Found header row
    }

    // 2. Detect Time Interval Bands (Rows)
    final timeRows = <_TimeRow>[];
    for (final row in rows) {
      for (final chunk in row) {
        final timeRange = _detectTimeRange(chunk.text);
        if (timeRange != null) {
          timeRows.add(_TimeRow(
            timeRange: timeRange,
            startY: chunk.y - 12.0,
            endY: chunk.bottom + 30.0,
          ));
          break;
        }
      }
    }

    if (dayColumns.isEmpty || timeRows.isEmpty) {
      return [];
    }

    // Sort columns by X and resolve midpoint boundaries
    dayColumns.sort((a, b) => a.startX.compareTo(b.startX));
    for (int i = 0; i < dayColumns.length - 1; i++) {
      final mid = (dayColumns[i].endX + dayColumns[i + 1].startX) / 2;
      dayColumns[i].endX = mid;
      dayColumns[i + 1].startX = mid;
    }

    final drafts = <ExtractedActivityDraft>[];
    final now = DateTime.now();

    for (final dayCol in dayColumns) {
      final dayDiff = dayCol.weekday - now.weekday;
      final targetDate = now.add(Duration(days: dayDiff));

      for (final timeRow in timeRows) {
        final cellChunks = chunks.where((c) {
          final inCol = c.x >= dayCol.startX && c.x <= dayCol.endX;
          final inRow = c.y >= timeRow.startY && c.y <= timeRow.endY;
          return inCol && inRow;
        }).toList();

        if (cellChunks.isEmpty) continue;

        final rawCellText = cellChunks.map((c) => c.text).join(' ').trim();
        if (_detectWeekday(rawCellText) != null || _detectTimeRange(rawCellText) != null) {
          continue;
        }

        final title = _cleanTitle(rawCellText);
        if (title.length < 3) continue;

        final location = instructions.readClassroom ? _detectLocation(rawCellText) : '';
        final faculty = instructions.readFaculty ? _detectFaculty(rawCellText) : null;
        final category = _detectCategory(rawCellText, instructions);
        final priority = category == ActivityCategory.exam
            ? ActivityPriority.high
            : (category == ActivityCategory.lab ? ActivityPriority.medium : ActivityPriority.medium);

        drafts.add(ExtractedActivityDraft(
          id: _uuid.v4(),
          title: title,
          weekday: dayCol.weekday,
          specificDate: targetDate,
          startHour: timeRow.timeRange.startHour,
          startMinute: timeRow.timeRange.startMinute,
          endHour: timeRow.timeRange.endHour,
          endMinute: timeRow.timeRange.endMinute,
          location: location,
          faculty: faculty,
          category: category,
          priority: priority,
          recurrence: const RecurrenceRule(type: RecurrenceType.weekly),
          confidence: ExtractionConfidence.high,
          isSelected: true,
        ));
      }
    }

    return drafts;
  }

  /// Parses text lines using regex heuristics for Days, Times, Rooms, and Subjects.
  static List<ExtractedActivityDraft> parseLines(
    String text,
    PdfImportInstructions instructions,
  ) {
    final drafts = <ExtractedActivityDraft>[];
    final lines = text.split(RegExp(r'\r?\n'));
    int currentWeekday = 1;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.length < 5) continue;

      final dayMatch = _detectWeekday(trimmed);
      if (dayMatch != null) {
        currentWeekday = dayMatch;
        if (trimmed.length < 12) continue;
      }

      final timeMatch = _detectTimeRange(trimmed);
      if (timeMatch == null) continue;

      final title = _cleanTitle(trimmed);
      if (title.isEmpty) continue;

      final location = instructions.readClassroom ? _detectLocation(trimmed) : '';
      final faculty = instructions.readFaculty ? _detectFaculty(trimmed) : null;
      final category = _detectCategory(trimmed, instructions);
      final priority = category == ActivityCategory.exam
          ? ActivityPriority.high
          : (category == ActivityCategory.lab ? ActivityPriority.medium : ActivityPriority.medium);

      final confidenceNotes = <String>[];
      var confidence = ExtractionConfidence.high;

      if (timeMatch.isApproximatedEnd) {
        confidence = ExtractionConfidence.medium;
        confidenceNotes.add('End time was approximated based on standard duration');
      }
      if (location.isEmpty && instructions.readClassroom) {
        confidenceNotes.add('Classroom not identified in text');
      }

      drafts.add(ExtractedActivityDraft(
        id: _uuid.v4(),
        title: title,
        location: location,
        faculty: faculty,
        category: category,
        priority: priority,
        weekday: currentWeekday,
        startHour: timeMatch.startHour,
        startMinute: timeMatch.startMinute,
        endHour: timeMatch.endHour,
        endMinute: timeMatch.endMinute,
        recurrence: RecurrenceRule(
          type: RecurrenceType.weekly,
          selectedWeekdays: [currentWeekday],
        ),
        confidence: confidence,
        confidenceNotes: confidenceNotes,
        isSelected: true,
      ));
    }

    return drafts;
  }

  /// Evaluates natural language constraints inside `instructions.customInstruction`.
  static List<ExtractedActivityDraft> applyUserInstructions({
    required List<ExtractedActivityDraft> drafts,
    required PdfImportInstructions instructions,
  }) {
    final custom = instructions.customInstruction.toLowerCase().trim();
    if (custom.isEmpty) return drafts;

    return drafts.where((draft) {
      final title = draft.title.toLowerCase();
      final dept = draft.department?.toLowerCase() ?? '';
      final sem = draft.semester?.toLowerCase() ?? '';

      // 1. Holiday filter
      if (custom.contains('ignore holiday') ||
          custom.contains('skip holiday') ||
          custom.contains('no holiday')) {
        if (title.contains('holiday') || title.contains('break') || title.contains('recess')) {
          return false;
        }
      }

      // 2. Weekend filter
      if (custom.contains('skip weekend') ||
          custom.contains('no saturday') ||
          custom.contains('no sunday')) {
        if (draft.weekday >= 6) {
          return false;
        }
      }

      // 3. Semester filter: e.g. "Semester 4" or "Sem 4"
      final semMatch = RegExp(r'sem(ester)?\s*([0-9]+)').firstMatch(custom);
      if (semMatch != null) {
        final targetSemNum = semMatch.group(2);
        if (targetSemNum != null) {
          if (sem.isNotEmpty && !sem.contains(targetSemNum)) {
            return false;
          }
          if (title.contains('sem') && !title.contains(targetSemNum)) {
            return false;
          }
        }
      }

      // 4. Department filter
      if (custom.contains('computer') || custom.contains('cs')) {
        if (dept.isNotEmpty && !dept.contains('computer') && !dept.contains('cs')) {
          return false;
        }
      }

      // 5. Labs only filter
      if (custom.contains('labs only') || custom.contains('only lab')) {
        if (draft.category != ActivityCategory.lab && !title.contains('lab')) {
          return false;
        }
      }

      // 6. Exams only filter
      if (custom.contains('exams only') || custom.contains('only exam')) {
        if (draft.category != ActivityCategory.exam && !title.contains('exam')) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Cross-references extracted drafts with existing database activities to flag collisions.
  static void detectDuplicates({
    required List<ExtractedActivityDraft> drafts,
    required List<ActivityModel> existingActivities,
  }) {
    for (final draft in drafts) {
      for (final existing in existingActivities) {
        final titleMatch = _isSimilarTitle(draft.title, existing.title);
        final sameWeekday = existing.date.weekday == draft.weekday ||
            (existing.recurrence.selectedWeekdays.contains(draft.weekday));
        final sameTime = existing.startTime.hour == draft.startHour &&
            (existing.startTime.minute - draft.startMinute).abs() <= 15;

        if (titleMatch && sameWeekday && sameTime) {
          draft.isDuplicate = true;
          draft.duplicateReason =
              "Already exists in your routine: '${existing.title}' on ${draft.dayName} at ${draft.timeFormatted.split(' - ').first}";
          draft.isSelected = false;
          break;
        }
      }
    }
  }

  static bool _isSimilarTitle(String a, String b) {
    final cleanA = a.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cleanB = b.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (cleanA.isEmpty || cleanB.isEmpty) return false;
    return cleanA == cleanB || cleanA.contains(cleanB) || cleanB.contains(cleanA);
  }

  static int? _detectWeekday(String line) {
    final lower = line.toLowerCase();
    if (lower.contains('monday') || lower.contains('mon:')) return 1;
    if (lower.contains('tuesday') || lower.contains('tue:')) return 2;
    if (lower.contains('wednesday') || lower.contains('wed:')) return 3;
    if (lower.contains('thursday') || lower.contains('thu:')) return 4;
    if (lower.contains('friday') || lower.contains('fri:')) return 5;
    if (lower.contains('saturday') || lower.contains('sat:')) return 6;
    if (lower.contains('sunday') || lower.contains('sun:')) return 7;
    return null;
  }

  static _ParsedTimeRange? _detectTimeRange(String line) {
    final rangeRegex = RegExp(
      r'(\d{1,2}):(\d{2})\s*(am|pm)?\s*(?:-|to|–)\s*(\d{1,2}):(\d{2})\s*(am|pm)?',
      caseSensitive: false,
    );
    final match = rangeRegex.firstMatch(line);
    if (match != null) {
      int sH = int.parse(match.group(1)!);
      int sM = int.parse(match.group(2)!);
      String? sMeridiem = match.group(3)?.toLowerCase();

      int eH = int.parse(match.group(4)!);
      int eM = int.parse(match.group(5)!);
      String? eMeridiem = match.group(6)?.toLowerCase() ?? sMeridiem;

      if (sMeridiem == 'pm' && sH < 12) sH += 12;
      if (sMeridiem == 'am' && sH == 12) sH = 0;
      if (eMeridiem == 'pm' && eH < 12) eH += 12;
      if (eMeridiem == 'am' && eH == 12) eH = 0;

      return _ParsedTimeRange(startHour: sH, startMinute: sM, endHour: eH, endMinute: eM);
    }

    final singleRegex = RegExp(r'(\d{1,2}):(\d{2})\s*(am|pm)', caseSensitive: false);
    final singleMatch = singleRegex.firstMatch(line);
    if (singleMatch != null) {
      int sH = int.parse(singleMatch.group(1)!);
      int sM = int.parse(singleMatch.group(2)!);
      String meridiem = singleMatch.group(3)!.toLowerCase();
      if (meridiem == 'pm' && sH < 12) sH += 12;
      if (meridiem == 'am' && sH == 12) sH = 0;

      int eH = (sH + 1) % 24;
      return _ParsedTimeRange(
        startHour: sH,
        startMinute: sM,
        endHour: eH,
        endMinute: sM,
        isApproximatedEnd: true,
      );
    }

    return null;
  }

  static String _cleanTitle(String line) {
    String cleaned = line;
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\d{1,2}:\d{2}\s*(am|pm)?\s*(?:-|to|–)\s*\d{1,2}:\d{2}\s*(am|pm)?', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\d{1,2}:\d{2}\s*(am|pm)?', caseSensitive: false), '');

    final faculty = _detectFaculty(cleaned);
    if (faculty != null && faculty.isNotEmpty) {
      cleaned = cleaned.replaceAll(faculty, '');
    }

    final location = _detectLocation(cleaned);
    if (location.isNotEmpty) {
      cleaned = cleaned.replaceAll(location, '');
    }

    cleaned = cleaned.replaceAll(RegExp(r'[\|\,\-\:]'), ' ');

    return cleaned.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _detectLocation(String line) {
    final roomMatch = RegExp(
      r'\b(Room\s*\d+[A-Z]?|Lab\s*(?:\d+[A-Z]?|[A-Z]\b|[A-Z]\d+)|Lecture\s*Hall\s*\d+|Hall\s*[0-9A-Z]+|Auditorium\s*[0-9A-Z]*|LH\s*\d+)\b',
      caseSensitive: false,
    ).firstMatch(line);
    return roomMatch?.group(0) ?? '';
  }

  static String? _detectFaculty(String line) {
    final facultyMatch = RegExp(
      r'\b(Prof\.|Dr\.|Professor)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\b',
    ).firstMatch(line);
    return facultyMatch?.group(0);
  }

  static ActivityCategory _detectCategory(String line, PdfImportInstructions instructions) {
    final lower = line.toLowerCase();
    if (instructions.readExam || lower.contains('exam') || lower.contains('midterm') || lower.contains('final test')) {
      return ActivityCategory.exam;
    }
    if (instructions.readAssignment || lower.contains('assignment') || lower.contains('submission')) {
      return ActivityCategory.assignment;
    }
    if (lower.contains('lab') || lower.contains('practical')) {
      return ActivityCategory.lab;
    }
    if (lower.contains('seminar') || lower.contains('meeting') || lower.contains('workshop')) {
      return ActivityCategory.meeting;
    }
    return ActivityCategory.lecture;
  }

  static List<ExtractedActivityDraft> _generateSampleTemplateDrafts({
    required PdfImportInstructions instructions,
    required String templateHint,
  }) {
    final drafts = <ExtractedActivityDraft>[];

    void addDraft({
      required String title,
      required String description,
      required String location,
      String? faculty,
      String? department,
      String? semester,
      required ActivityCategory category,
      required ActivityPriority priority,
      required int weekday,
      required int startHour,
      required int startMinute,
      required int endHour,
      required int endMinute,
    }) {
      drafts.add(
        ExtractedActivityDraft(
          id: _uuid.v4(),
          title: title,
          description: description,
          location: instructions.readClassroom ? location : '',
          faculty: instructions.readFaculty ? faculty : null,
          department: department,
          semester: semester,
          category: category,
          priority: priority,
          weekday: weekday,
          startHour: startHour,
          startMinute: startMinute,
          endHour: endHour,
          endMinute: endMinute,
          recurrence: RecurrenceRule(
            type: RecurrenceType.weekly,
            selectedWeekdays: [weekday],
          ),
          confidence: ExtractionConfidence.medium,
          confidenceNotes: const ['Sample template activity. Please verify timings.'],
          isSelected: true,
        ),
      );
    }

    if (templateHint == 'cs_semester_4') {
      addDraft(
        title: 'Data Structures & Algorithms',
        description: 'CS401: Trees, graphs, dynamic programming',
        location: 'Room 204',
        faculty: 'Prof. Alan Turing',
        department: 'Computer Engineering',
        semester: 'Semester 4',
        category: ActivityCategory.lecture,
        priority: ActivityPriority.high,
        weekday: 1,
        startHour: 9,
        startMinute: 0,
        endHour: 10,
        endMinute: 30,
      );

      addDraft(
        title: 'Database Systems & SQL',
        description: 'CS404: Relational algebra, ACID properties',
        location: 'Room 101',
        faculty: 'Dr. Edgar Codd',
        department: 'Computer Engineering',
        semester: 'Semester 4',
        category: ActivityCategory.lecture,
        priority: ActivityPriority.high,
        weekday: 2,
        startHour: 10,
        startMinute: 0,
        endHour: 11,
        endMinute: 30,
      );

      addDraft(
        title: 'Operating Systems Lab',
        description: 'CS406L: POSIX threads, semaphores, shell',
        location: 'Lab A1',
        faculty: 'Prof. Linus Torvalds',
        department: 'Computer Engineering',
        semester: 'Semester 4',
        category: ActivityCategory.lab,
        priority: ActivityPriority.medium,
        weekday: 3,
        startHour: 14,
        startMinute: 0,
        endHour: 16,
        endMinute: 0,
      );

      addDraft(
        title: 'Computer Networks',
        description: 'CS407: TCP/IP, OSI model, socket programming',
        location: 'Room 302',
        faculty: 'Dr. Vint Cerf',
        department: 'Computer Engineering',
        semester: 'Semester 4',
        category: ActivityCategory.lecture,
        priority: ActivityPriority.medium,
        weekday: 4,
        startHour: 11,
        startMinute: 0,
        endHour: 12,
        endMinute: 30,
      );
    } else if (templateHint == 'exam_schedule') {
      addDraft(
        title: 'CS401 Algorithms Midterm Exam',
        description: 'Covers Chapters 1-5, algorithms, big-O, data structures',
        location: 'Examination Hall 1',
        faculty: 'Prof. Alan Turing',
        department: 'Computer Engineering',
        semester: 'Semester 4',
        category: ActivityCategory.study,
        priority: ActivityPriority.high,
        weekday: 1,
        startHour: 10,
        startMinute: 0,
        endHour: 12,
        endMinute: 0,
      );

      addDraft(
        title: 'CS404 Database Systems Midterm Exam',
        description: 'SQL queries, relational algebra, normal forms',
        location: 'Examination Hall 2',
        faculty: 'Dr. Edgar Codd',
        department: 'Computer Engineering',
        semester: 'Semester 4',
        category: ActivityCategory.study,
        priority: ActivityPriority.high,
        weekday: 3,
        startHour: 14,
        startMinute: 0,
        endHour: 16,
        endMinute: 0,
      );
    } else if (templateHint == 'general_routine') {
      addDraft(
        title: 'Morning Cardio & Workout',
        description: 'Aerobic fitness and stretching routine',
        location: 'Fitness Center / Home Gym',
        category: ActivityCategory.health,
        priority: ActivityPriority.medium,
        weekday: 1,
        startHour: 7,
        startMinute: 0,
        endHour: 8,
        endMinute: 0,
      );

      addDraft(
        title: 'Daily Team Standup & Sync',
        description: 'Sprint alignment and priority checkpoint',
        location: 'Conference Room A / Online',
        category: ActivityCategory.work,
        priority: ActivityPriority.high,
        weekday: 1,
        startHour: 9,
        startMinute: 30,
        endHour: 10,
        endMinute: 0,
      );

      addDraft(
        title: 'Deep Focus: Project Execution',
        description: 'Dedicated focus block for core deliverables',
        location: 'Main Workspace',
        category: ActivityCategory.work,
        priority: ActivityPriority.high,
        weekday: 2,
        startHour: 10,
        startMinute: 30,
        endHour: 12,
        endMinute: 30,
      );

      addDraft(
        title: 'Strategy Review & Skill Learning',
        description: 'Skill development, reading, and research',
        location: 'Library / Study Desk',
        category: ActivityCategory.study,
        priority: ActivityPriority.medium,
        weekday: 3,
        startHour: 16,
        startMinute: 0,
        endHour: 17,
        endMinute: 30,
      );

      addDraft(
        title: 'Weekly Review & Routine Planning',
        description: 'Review achievements, track habits, and set upcoming milestones',
        location: 'Home Office',
        category: ActivityCategory.routine,
        priority: ActivityPriority.low,
        weekday: 5,
        startHour: 17,
        startMinute: 0,
        endHour: 18,
        endMinute: 0,
      );
    }

    return drafts;
  }
}

class _ByteRange {
  final int start;
  final int end;
  const _ByteRange(this.start, this.end);
}

class _ParsedTimeRange {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final bool isApproximatedEnd;

  _ParsedTimeRange({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.isApproximatedEnd = false,
  });
}

class _DayColumn {
  final int weekday;
  double startX;
  double endX;
  final String headerText;

  _DayColumn({
    required this.weekday,
    required this.startX,
    required this.endX,
    required this.headerText,
  });
}

class _TimeRow {
  final _ParsedTimeRange timeRange;
  double startY;
  double endY;

  _TimeRow({
    required this.timeRange,
    required this.startY,
    required this.endY,
  });
}

// Backwards compatibility aliases
typedef PdfExtractionService = PdfParserService;
typedef PdfTextParser = PdfParserService;

