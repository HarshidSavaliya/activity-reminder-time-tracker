import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../models/enums/activity_category.dart';
import '../../models/enums/activity_priority.dart';
import '../../models/extracted_activity_draft.dart';
import '../../models/pdf_import_instructions.dart';
import '../../models/recurrence_rule.dart';
import 'storage_service.dart';

/// Exception thrown when an Adobe Acrobat Services / Extract API request fails.
class AdobeApiException implements Exception {
  final String message;
  final int? statusCode;

  const AdobeApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Service that leverages Adobe Acrobat Services (PDF Extract API & PDF Embed API)
/// to accurately extract tabular timetables, college schedules, and daily routines
/// from native or scanned PDF documents.
///
/// Adobe Sensei AI accurately parses complex 2D table matrices, identifying cell bounds,
/// rows, columns, and text elements with high structural fidelity.
class AdobePdfService {
  static const String storageKeyClientId = 'adobe_client_id';
  static const String storageKeyClientSecret = 'adobe_client_secret';
  static const String storageKeyEmbedApiKey = 'adobe_embed_api_key';

  static const String defaultClientId = '0b559d5f4eef460f9b53692462659897';
  static const String defaultClientSecret = 'p8e-_w3F-a9kInYRUcZAaMzlBkaZdBgKXeuZ';

  final StorageService? storage;
  final http.Client _client;
  final String? _defaultClientId;
  final String? _defaultClientSecret;
  final Uuid _uuid = const Uuid();

  AdobePdfService({
    this.storage,
    http.Client? client,
    String? defaultClientId = defaultClientId,
    String? defaultClientSecret = defaultClientSecret,
  })  : _client = client ?? http.Client(),
        // ignore: prefer_initializing_formals
        _defaultClientId = defaultClientId,
        // ignore: prefer_initializing_formals
        _defaultClientSecret = defaultClientSecret;

  /// Retrieves the active Adobe Client ID (API Key).
  String? getClientId() {
    final fromStorage = storage?.getString(storageKeyClientId);
    if (fromStorage != null && fromStorage.trim().isNotEmpty) {
      return fromStorage.trim();
    }
    const fromDefine = String.fromEnvironment('ADOBE_CLIENT_ID');
    if (fromDefine.isNotEmpty) return fromDefine;

    try {
      final fromEnv = Platform.environment['ADOBE_CLIENT_ID'];
      if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    } catch (_) {}

    final defaultId = _defaultClientId;
    if (defaultId != null && defaultId.isNotEmpty) {
      return defaultId;
    }

    return null;
  }

  /// Retrieves the active Adobe Client Secret.
  String? getClientSecret() {
    final fromStorage = storage?.getString(storageKeyClientSecret);
    if (fromStorage != null && fromStorage.trim().isNotEmpty) {
      return fromStorage.trim();
    }
    const fromDefine = String.fromEnvironment('ADOBE_CLIENT_SECRET');
    if (fromDefine.isNotEmpty) return fromDefine;

    try {
      final fromEnv = Platform.environment['ADOBE_CLIENT_SECRET'];
      if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    } catch (_) {}

    final defaultSecret = _defaultClientSecret;
    if (defaultSecret != null && defaultSecret.isNotEmpty) {
      return defaultSecret;
    }

    return null;
  }

  /// Retrieves the Adobe Embed API Key (if distinct from Client ID).
  String? getEmbedApiKey() {
    final fromStorage = storage?.getString(storageKeyEmbedApiKey);
    if (fromStorage != null && fromStorage.trim().isNotEmpty) {
      return fromStorage.trim();
    }
    return getClientId();
  }

  /// Persists Adobe credentials into storage.
  Future<void> saveCredentials({
    required String clientId,
    required String clientSecret,
    String? embedApiKey,
  }) async {
    if (storage != null) {
      await storage!.setString(storageKeyClientId, clientId.trim());
      await storage!.setString(storageKeyClientSecret, clientSecret.trim());
      if (embedApiKey != null && embedApiKey.trim().isNotEmpty) {
        await storage!.setString(storageKeyEmbedApiKey, embedApiKey.trim());
      }
    }
  }

  /// Removes stored Adobe credentials.
  Future<void> clearCredentials() async {
    if (storage != null) {
      await storage!.setString(storageKeyClientId, '');
      await storage!.setString(storageKeyClientSecret, '');
      await storage!.setString(storageKeyEmbedApiKey, '');
    }
  }

  /// Whether valid Adobe PDF Services credentials are configured.
  bool get hasCredentials {
    final cid = getClientId();
    final sec = getClientSecret();
    return cid != null && cid.isNotEmpty && sec != null && sec.isNotEmpty;
  }

  /// Whether an Adobe Embed API Key is available.
  bool get hasEmbedKey {
    final key = getEmbedApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Exchanges Client ID and Client Secret for an Adobe OAuth access token.
  Future<String> fetchAccessToken({
    String? explicitClientId,
    String? explicitClientSecret,
  }) async {
    final clientId = explicitClientId ?? getClientId();
    final clientSecret = explicitClientSecret ?? getClientSecret();

    if (clientId == null || clientId.isEmpty || clientSecret == null || clientSecret.isEmpty) {
      throw const AdobeApiException(
        'Adobe PDF Services credentials missing. Please configure Client ID and Client Secret in Settings.',
      );
    }

    try {
      // 1. Try standard Adobe PDF Services token endpoint
      final tokenUri = Uri.parse('https://pdf-services.adobe.io/token');
      final response = await _client.post(
        tokenUri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['access_token'] as String?;
        if (token != null && token.isNotEmpty) {
          return token;
        }
      }

      // 2. Fallback: Adobe IMS OAuth v3 server-to-server endpoint
      final imsUri = Uri.parse('https://ims-na1.adobelogin.com/ims/token/v3');
      final imsResponse = await _client.post(
        imsUri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'client_credentials',
          'scope': 'openid,AdobeID,read_organizations',
        },
      );

      if (imsResponse.statusCode == 200) {
        final imsData = jsonDecode(imsResponse.body) as Map<String, dynamic>;
        final token = imsData['access_token'] as String?;
        if (token != null && token.isNotEmpty) {
          return token;
        }
      }

      throw AdobeApiException(
        'Failed to authenticate with Adobe Services (${response.statusCode}): ${response.body}',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is AdobeApiException) rethrow;
      throw AdobeApiException('Network error communicating with Adobe Auth: $e');
    }
  }

  /// Uploads PDF bytes, triggers Adobe PDF Extract API, and parses structured output.
  Future<List<ExtractedActivityDraft>> extractActivitiesFromPdf({
    required Uint8List pdfBytes,
    required String filename,
    PdfImportInstructions? instructions,
    String? explicitClientId,
    String? explicitClientSecret,
  }) async {
    final effectiveInstructions = instructions ?? PdfImportInstructions();
    final clientId = explicitClientId ?? getClientId();
    if (clientId == null || clientId.isEmpty) {
      throw const AdobeApiException(
        'Adobe Client ID is missing. Please configure Adobe credentials in settings.',
      );
    }

    final accessToken = await fetchAccessToken(
      explicitClientId: clientId,
      explicitClientSecret: explicitClientSecret,
    );

    // Step 1: Request pre-signed Asset upload URI
    final assetUri = Uri.parse('https://pdf-services.adobe.io/assets');
    final assetResponse = await _client.post(
      assetUri,
      headers: {
        'x-api-key': clientId,
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'mediaType': 'application/pdf'}),
    );

    if (assetResponse.statusCode != 200) {
      throw AdobeApiException(
        'Adobe asset registration failed (${assetResponse.statusCode}): ${assetResponse.body}',
        statusCode: assetResponse.statusCode,
      );
    }

    final assetData = jsonDecode(assetResponse.body) as Map<String, dynamic>;
    final assetId = assetData['assetID'] as String?;
    final uploadUriStr = assetData['uploadUri'] as String?;

    if (assetId == null || uploadUriStr == null) {
      throw const AdobeApiException('Invalid asset response from Adobe Services.');
    }

    // Step 2: Upload PDF document bytes
    final uploadResponse = await _client.put(
      Uri.parse(uploadUriStr),
      headers: {'Content-Type': 'application/pdf'},
      body: pdfBytes,
    );

    if (uploadResponse.statusCode != 200 && uploadResponse.statusCode != 201) {
      throw AdobeApiException(
        'Failed to upload PDF bytes to Adobe cloud storage (${uploadResponse.statusCode}).',
        statusCode: uploadResponse.statusCode,
      );
    }

    // Step 3: Trigger PDF Extract operation
    final extractUri = Uri.parse('https://pdf-services.adobe.io/operation/extractpdf');
    final extractResponse = await _client.post(
      extractUri,
      headers: {
        'x-api-key': clientId,
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'assetID': assetId,
        'elementsToExtract': ['text', 'tables'],
      }),
    );

    if (extractResponse.statusCode != 201) {
      throw AdobeApiException(
        'Adobe Extract operation creation failed (${extractResponse.statusCode}): ${extractResponse.body}',
        statusCode: extractResponse.statusCode,
      );
    }

    final pollUrlStr = extractResponse.headers['location'] ?? extractResponse.headers['Location'];
    if (pollUrlStr == null) {
      throw const AdobeApiException('Missing location status header from Adobe Extract response.');
    }

    // Step 4: Poll job status until done (max 30 retries, 1s interval)
    String? downloadUriStr;
    final pollUri = Uri.parse(pollUrlStr);

    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 1));
      final statusResponse = await _client.get(
        pollUri,
        headers: {
          'x-api-key': clientId,
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (statusResponse.statusCode == 200) {
        final statusData = jsonDecode(statusResponse.body) as Map<String, dynamic>;
        final status = statusData['status'] as String?;

        if (status == 'done') {
          downloadUriStr = statusData['content']?['downloadUri'] as String?;
          break;
        } else if (status == 'failed') {
          final errorMsg = statusData['error']?['message'] ?? 'Adobe extraction job failed.';
          throw AdobeApiException(errorMsg.toString());
        }
      }
    }

    if (downloadUriStr == null) {
      throw const AdobeApiException('Adobe PDF Extract timed out while processing document.');
    }

    // Step 5: Download extracted result (direct JSON or ZIP package)
    final downloadResponse = await _client.get(Uri.parse(downloadUriStr));
    if (downloadResponse.statusCode != 200) {
      throw AdobeApiException(
        'Failed to download Adobe extraction package (${downloadResponse.statusCode}).',
        statusCode: downloadResponse.statusCode,
      );
    }

    final bodyBytes = downloadResponse.bodyBytes;
    Map<String, dynamic> adobeStructured;

    if (bodyBytes.isNotEmpty && (bodyBytes[0] == 0x7B || bodyBytes[0] == 0x5B)) {
      // Direct structuredData.json payload
      final rawJson = utf8.decode(bodyBytes);
      adobeStructured = jsonDecode(rawJson) as Map<String, dynamic>;
    } else {
      // Unzip structuredData.json from archive
      final archive = ZipDecoder().decodeBytes(bodyBytes);
      final jsonFile = archive.firstWhere(
        (file) => file.name.endsWith('structuredData.json'),
        orElse: () => throw const AdobeApiException('structuredData.json not found in Adobe output ZIP.'),
      );

      final rawJson = utf8.decode(jsonFile.content as List<int>);
      adobeStructured = jsonDecode(rawJson) as Map<String, dynamic>;
    }

    return parseAdobeStructuredJson(
      data: adobeStructured,
      instructions: effectiveInstructions,
    );
  }

  /// Parses Adobe Extract API's `structuredData.json` into timetable drafts.
  /// If the PDF contains NO timetable activities, returns an empty list.
  /// GUARANTEE: NEVER injects dummy or fake data!
  List<ExtractedActivityDraft> parseAdobeStructuredJson({
    required Map<String, dynamic> data,
    required PdfImportInstructions instructions,
  }) {
    final elements = (data['elements'] as List<dynamic>?) ?? [];
    if (elements.isEmpty) {
      return [];
    }

    final drafts = <ExtractedActivityDraft>[];

    // Adobe elements have "Path", "Text", "Bounds", "Page".
    // 1. First, look for Table elements (Adobe detects tabular timetable grids with Sensei AI)
    final tableElements = elements.where((e) {
      final path = e['Path']?.toString() ?? '';
      return path.contains('Table') && e['Text'] != null;
    }).toList();

    if (tableElements.isNotEmpty) {
      final tableDrafts = _parseTableElements(tableElements, instructions);
      drafts.addAll(tableDrafts);
    }

    // 2. If table parsing did not yield activities, parse general text blocks with time & day markers
    if (drafts.isEmpty) {
      final textLines = elements
          .where((e) => e['Text'] != null)
          .map((e) => e['Text'].toString().trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final lineDrafts = _parseTextLines(textLines, instructions);
      drafts.addAll(lineDrafts);
    }

    // Sort chronologically: Monday to Sunday, then morning to evening
    drafts.sort((a, b) {
      if (a.weekday != b.weekday) return a.weekday.compareTo(b.weekday);
      if (a.startHour != b.startHour) return a.startHour.compareTo(b.startHour);
      return a.startMinute.compareTo(b.startMinute);
    });

    // CRITICAL REQUIREMENT: Do NOT inject dummy data if drafts is empty!
    return drafts;
  }

  List<ExtractedActivityDraft> _parseTableElements(
    List<dynamic> tableElements,
    PdfImportInstructions instructions,
  ) {
    final drafts = <ExtractedActivityDraft>[];

    // Group elements by table identifier, row index, and column index
    // Path examples: //Document/Sect/Table/TR[2]/TD[3]/P or //Document/Table[1]/TR[1]/TH[1]
    final tableMap = <String, Map<int, Map<int, List<String>>>>{};

    for (final elem in tableElements) {
      final path = elem['Path']?.toString() ?? '';
      final text = elem['Text']?.toString().trim() ?? '';
      if (text.isEmpty) continue;

      final tableMatch = RegExp(r'(.*?/Table(?:\[\d+\])?)').firstMatch(path);
      final tableKey = tableMatch?.group(1) ?? 'default';

      final trMatch = RegExp(r'/TR(?:\[(\d+)\])?').firstMatch(path);
      final rowIndex = trMatch != null && trMatch.group(1) != null ? int.parse(trMatch.group(1)!) : 1;

      final colMatch = RegExp(r'/(?:TD|TH)(?:\[(\d+)\])?').firstMatch(path);
      final colIndex = colMatch != null && colMatch.group(1) != null ? int.parse(colMatch.group(1)!) : 1;

      tableMap
          .putIfAbsent(tableKey, () => {})
          .putIfAbsent(rowIndex, () => {})
          .putIfAbsent(colIndex, () => [])
          .add(text);
    }

    for (final rows in tableMap.values) {
      if (rows.isEmpty) continue;

      final sortedRowIndices = rows.keys.toList()..sort();
      final minRowIndex = sortedRowIndices.first;
      final headerRow = rows[minRowIndex] ?? {};

      // 1. Detect weekday mapping from header row columns
      final colWeekdayMap = <int, int>{};
      for (final colEntry in headerRow.entries) {
        final day = _detectWeekday(colEntry.value.join(' '));
        if (day != null) {
          colWeekdayMap[colEntry.key] = day;
        }
      }

      // Check if columns map 1-to-1 to calendar weekdays (e.g. 1: Monday .. 7: Sunday)
      // Even if some column headers had OCR noise or were image-only, infer sequence
      if (colWeekdayMap.length >= 2) {
        int directMatchCount = 0;
        for (final entry in colWeekdayMap.entries) {
          if (entry.key == entry.value) directMatchCount++;
        }
        if (directMatchCount >= 2) {
          final maxCol = rows.values
              .map((r) => r.keys.isEmpty ? 1 : r.keys.reduce((a, b) => a > b ? a : b))
              .fold(1, (a, b) => a > b ? a : b);
          final totalDays = maxCol >= 7 ? 7 : 5;
          for (int c = 1; c <= totalDays; c++) {
            colWeekdayMap.putIfAbsent(c, () => c);
          }
        }
      }

      final is2DMatrix = colWeekdayMap.length >= 2;

      if (is2DMatrix) {
        // Parse 2D Grid Matrix: each cell in data rows is an activity for that column's weekday
        for (final rIdx in sortedRowIndices) {
          if (rIdx == minRowIndex) continue; // Skip header row
          final rowCells = rows[rIdx] ?? {};

          // Check if row has a common time marker in column 1 (e.g. time column)
          final rowTime = (rowCells.containsKey(1) && !colWeekdayMap.containsKey(1))
              ? _detectTimeRange(rowCells[1]!.join(' '))
              : null;

          for (final cellEntry in rowCells.entries) {
            final colIdx = cellEntry.key;
            final weekday = colWeekdayMap[colIdx];
            if (weekday == null) continue;

            final cellText = cellEntry.value.join(' ').trim();
            if (cellText.isEmpty) continue;

            final timeRange = _detectTimeRange(cellText) ?? rowTime;
            if (timeRange != null) {
              final title = _extractTitle(cellText);
              if (title.isNotEmpty && title.length >= 2) {
                final location = instructions.readClassroom ? _detectLocation(cellText) : '';
                final faculty = instructions.readFaculty ? _detectFaculty(cellText) : null;
                final category = _detectCategory(title, cellText);

                drafts.add(
                  ExtractedActivityDraft(
                    id: _uuid.v4(),
                    title: title,
                    description: 'Extracted via Adobe PDF Services',
                    location: location,
                    faculty: faculty,
                    category: category,
                    priority: (instructions.extractExams && title.toLowerCase().contains('exam'))
                        ? ActivityPriority.high
                        : ActivityPriority.medium,
                    weekday: weekday,
                    startHour: timeRange.startHour,
                    startMinute: timeRange.startMinute,
                    endHour: timeRange.endHour,
                    endMinute: timeRange.endMinute,
                    recurrence: RecurrenceRule(
                      type: RecurrenceType.weekly,
                      selectedWeekdays: [weekday],
                    ),
                    confidence: ExtractionConfidence.high,
                    confidenceNotes: const ['Extracted using Adobe Sensei AI Table Recognition'],
                    isSelected: true,
                  ),
                );
              }
            }
          }
        }
      } else {
        // Sequential Row-based Table: each row is an activity (or day section)
        int currentWeekday = 1;

        for (final rIdx in sortedRowIndices) {
          final rowCells = rows[rIdx] ?? {};
          final combinedRowText = rowCells.values.map((c) => c.join(' ')).join(' | ');

          final detectedDay = _detectWeekday(combinedRowText);
          if (detectedDay != null) {
            currentWeekday = detectedDay;
          }

          final timeRange = _detectTimeRange(combinedRowText);
          if (timeRange != null) {
            final title = _extractTitle(combinedRowText);
            if (title.isNotEmpty && title.length >= 2) {
              final location = instructions.readClassroom ? _detectLocation(combinedRowText) : '';
              final faculty = instructions.readFaculty ? _detectFaculty(combinedRowText) : null;
              final category = _detectCategory(title, combinedRowText);

              drafts.add(
                ExtractedActivityDraft(
                  id: _uuid.v4(),
                  title: title,
                  description: 'Extracted via Adobe PDF Services',
                  location: location,
                  faculty: faculty,
                  category: category,
                  priority: (instructions.extractExams && title.toLowerCase().contains('exam'))
                      ? ActivityPriority.high
                      : ActivityPriority.medium,
                  weekday: currentWeekday,
                  startHour: timeRange.startHour,
                  startMinute: timeRange.startMinute,
                  endHour: timeRange.endHour,
                  endMinute: timeRange.endMinute,
                  recurrence: RecurrenceRule(
                    type: RecurrenceType.weekly,
                    selectedWeekdays: [currentWeekday],
                  ),
                  confidence: ExtractionConfidence.high,
                  confidenceNotes: const ['Extracted using Adobe Sensei AI Table Recognition'],
                  isSelected: true,
                ),
              );
            }
          }
        }
      }
    }

    return drafts;
  }

  List<ExtractedActivityDraft> _parseTextLines(
    List<String> lines,
    PdfImportInstructions instructions,
  ) {
    final drafts = <ExtractedActivityDraft>[];
    int currentWeekday = 1;

    for (final line in lines) {
      final detectedDay = _detectWeekday(line);
      if (detectedDay != null) {
        currentWeekday = detectedDay;
      }

      final timeRange = _detectTimeRange(line);
      if (timeRange != null) {
        final title = _extractTitle(line);
        if (title.isNotEmpty && title.length > 2) {
          final location = instructions.readClassroom ? _detectLocation(line) : '';
          final faculty = instructions.readFaculty ? _detectFaculty(line) : null;
          final category = _detectCategory(title, line);

          drafts.add(
            ExtractedActivityDraft(
              id: _uuid.v4(),
              title: title,
              description: 'Extracted via Adobe PDF Services',
              location: location,
              faculty: faculty,
              category: category,
              priority: (instructions.extractExams && title.toLowerCase().contains('exam'))
                  ? ActivityPriority.high
                  : ActivityPriority.medium,
              weekday: currentWeekday,
              startHour: timeRange.startHour,
              startMinute: timeRange.startMinute,
              endHour: timeRange.endHour,
              endMinute: timeRange.endMinute,
              recurrence: RecurrenceRule(
                type: RecurrenceType.weekly,
                selectedWeekdays: [currentWeekday],
              ),
              confidence: ExtractionConfidence.high,
              confidenceNotes: const ['Extracted via Adobe PDF Services AI'],
              isSelected: true,
            ),
          );
        }
      }
    }

    return drafts;
  }

  static int? _detectWeekday(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('monday') || lower.contains('mon:') || RegExp(r'\bmon\b').hasMatch(lower)) return 1;
    if (lower.contains('tuesday') || lower.contains('tue:') || RegExp(r'\btue\b').hasMatch(lower)) return 2;
    if (lower.contains('wednesday') || lower.contains('wed:') || RegExp(r'\bwed\b').hasMatch(lower)) return 3;
    if (lower.contains('thursday') || lower.contains('thu:') || RegExp(r'\bthu\b').hasMatch(lower)) return 4;
    if (lower.contains('friday') || lower.contains('fri:') || RegExp(r'\bfri\b').hasMatch(lower)) return 5;
    if (lower.contains('saturday') || lower.contains('sat:') || RegExp(r'\bsat\b').hasMatch(lower)) return 6;
    if (lower.contains('sunday') || lower.contains('sun:') || RegExp(r'\bsun\b').hasMatch(lower)) return 7;
    return null;
  }

  static _AdobeTimeRange? _detectTimeRange(String text) {
    final rangeRegex = RegExp(
      r'(\d{1,2}):(\d{2})\s*(am|pm)?\s*(?:-|to|–)\s*(\d{1,2}):(\d{2})\s*(am|pm)?',
      caseSensitive: false,
    );
    final match = rangeRegex.firstMatch(text);
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

      return _AdobeTimeRange(startHour: sH, startMinute: sM, endHour: eH, endMinute: eM);
    }

    final singleRegex = RegExp(r'(\d{1,2}):(\d{2})\s*(am|pm)', caseSensitive: false);
    final singleMatch = singleRegex.firstMatch(text);
    if (singleMatch != null) {
      int sH = int.parse(singleMatch.group(1)!);
      int sM = int.parse(singleMatch.group(2)!);
      String meridiem = singleMatch.group(3)!.toLowerCase();
      if (meridiem == 'pm' && sH < 12) sH += 12;
      if (meridiem == 'am' && sH == 12) sH = 0;

      int eH = (sH + 1) % 24;
      return _AdobeTimeRange(startHour: sH, startMinute: sM, endHour: eH, endMinute: sM);
    }

    final singleHourRegex = RegExp(r'\b(\d{1,2})\s*(am|pm)\b', caseSensitive: false);
    final hourMatch = singleHourRegex.firstMatch(text);
    if (hourMatch != null) {
      int sH = int.parse(hourMatch.group(1)!);
      int sM = 0;
      String meridiem = hourMatch.group(2)!.toLowerCase();
      if (meridiem == 'pm' && sH < 12) sH += 12;
      if (meridiem == 'am' && sH == 12) sH = 0;

      int eH = (sH + 1) % 24;
      return _AdobeTimeRange(startHour: sH, startMinute: sM, endHour: eH, endMinute: 0);
    }

    return null;
  }

  static String _extractTitle(String text) {
    String cleaned = text;

    // Remove day names
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(mon|tue|wed|thu|fri|sat|sun)\b', caseSensitive: false),
      '',
    );

    // Remove time ranges
    cleaned = cleaned.replaceAll(
      RegExp(r'\d{1,2}:\d{2}\s*(am|pm)?\s*(?:-|to|–)\s*\d{1,2}:\d{2}\s*(am|pm)?', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\d{1,2}:\d{2}\s*(am|pm)?', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b\d{1,2}\s*(am|pm)\b', caseSensitive: false), '');

    // Remove faculty name if present
    final faculty = _detectFaculty(cleaned);
    if (faculty != null && faculty.isNotEmpty) {
      cleaned = cleaned.replaceAll(faculty, '');
    }

    // Remove location if present
    final location = _detectLocation(cleaned);
    if (location.isNotEmpty) {
      cleaned = cleaned.replaceAll(location, '');
    }

    cleaned = cleaned.replaceAll(RegExp(r'[\|\,\-\:]'), ' ');
    return cleaned.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _detectLocation(String text) {
    final roomMatch = RegExp(
      r'\b(Room\s*\d+[A-Z]?|Lab\s*(?:\d+[A-Z]?|[A-Z]\b|[A-Z]\d+)|Lecture\s*Hall\s*\d+|Hall\s*[0-9A-Z]+|Auditorium\s*[0-9A-Z]*|LH\s*\d+)\b',
      caseSensitive: false,
    ).firstMatch(text);
    return roomMatch?.group(0) ?? '';
  }

  static String? _detectFaculty(String text) {
    final facultyMatch = RegExp(
      r'\b(Prof\.|Dr\.|Professor)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\b',
    ).firstMatch(text);
    return facultyMatch?.group(0);
  }

  static ActivityCategory _detectCategory(String title, String context) {
    final combined = '$title $context'.toLowerCase();
    if (combined.contains('lab') || combined.contains('practical')) return ActivityCategory.lab;
    if (combined.contains('workout') || combined.contains('gym') || combined.contains('fitness')) {
      return ActivityCategory.health;
    }
    if (combined.contains('standup') || combined.contains('sync') || combined.contains('meeting')) {
      return ActivityCategory.meeting;
    }
    if (combined.contains('exam') || combined.contains('midterm') || combined.contains('test')) {
      return ActivityCategory.study;
    }
    return ActivityCategory.lecture;
  }
}

class _AdobeTimeRange {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const _AdobeTimeRange({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });
}
