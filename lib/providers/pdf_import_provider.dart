import 'package:flutter/foundation.dart';
import '../core/services/pdf_history_service.dart';
import '../core/services/pdf_parser_service.dart';
import '../models/activity_model.dart';
import '../models/extracted_activity_draft.dart';
import '../models/pdf_import_instructions.dart';
import '../models/pdf_import_record.dart';

/// State orchestrator for the multi-step PDF Timetable Import Wizard:
/// 1. Upload Document
/// 2. Specify Instructions & Timetable Preferences
/// 3. Heuristic / Adobe Multimodal Extraction & Processing
/// 4. Categorized Review & Bulk Adjustments
class PdfImportProvider extends ChangeNotifier {
  final TimetableParser _parser;
  final PdfHistoryService? historyService;

  int _currentStep = 0;
  Uint8List? _fileBytes;
  String? _fileName;
  PdfImportInstructions _instructions = PdfImportInstructions();
  List<ExtractedActivityDraft> _drafts = [];
  bool _isProcessing = false;
  String? _errorMessage;
  bool _isScanned = false;
  int _selectedReviewTab = 0; // 0: Ready, 1: Conflicts, 2: Incomplete

  PdfImportProvider({
    TimetableParser? parser,
    this.historyService,
  })  : _parser = parser ?? PdfParserService();

  int get currentStep => _currentStep;
  Uint8List? get fileBytes => _fileBytes;
  String? get fileName => _fileName;
  PdfImportInstructions get instructions => _instructions;
  List<ExtractedActivityDraft> get allDrafts => List.unmodifiable(_drafts);
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  bool get isScanned => _isScanned;
  int get selectedReviewTab => _selectedReviewTab;

  /// Drafts that are fully formed, have valid times, and have no schedule collisions.
  List<ExtractedActivityDraft> get readyDrafts {
    return _drafts.where((d) => d.isReady).toList();
  }

  /// Drafts that have detected overlaps or duplicate status.
  List<ExtractedActivityDraft> get conflictingDrafts {
    return _drafts.where((d) => d.hasConflict).toList();
  }

  /// Drafts with incomplete data (e.g. missing title or zero duration).
  List<ExtractedActivityDraft> get incompleteDrafts {
    return _drafts.where((d) => d.isIncomplete).toList();
  }

  void setStep(int step) {
    if (_currentStep == step) return;
    _currentStep = step;
    notifyListeners();
  }

  void setSelectedReviewTab(int tabIndex) {
    if (_selectedReviewTab == tabIndex) return;
    _selectedReviewTab = tabIndex;
    notifyListeners();
  }

  void setFile(Uint8List bytes, String name) {
    _fileBytes = bytes;
    _fileName = name;
    _errorMessage = null;
    notifyListeners();
  }

  void clearFile() {
    _fileBytes = null;
    _fileName = null;
    _drafts = [];
    _errorMessage = null;
    notifyListeners();
  }

  void updateInstructions(PdfImportInstructions newInstructions) {
    _instructions = newInstructions;
    notifyListeners();
  }

  /// Runs the extraction pipeline using the formal [TimetableParser] interface.
  Future<bool> startExtraction(
    List<ActivityModel> existingActivities, {
    String? explicitAdobeClientId,
    String? explicitAdobeClientSecret,
  }) async {
    if (_fileBytes == null || _fileName == null) {
      _errorMessage = 'No file selected. Please select a PDF document first.';
      notifyListeners();
      return false;
    }

    _isProcessing = true;
    _errorMessage = null;
    _currentStep = 2; // Processing screen
    notifyListeners();

    try {
      final results = await _parser.parseTimetable(
        pdfBytes: _fileBytes!,
        filename: _fileName!,
        instructions: _instructions,
        existingActivities: existingActivities,
        explicitAdobeClientId: explicitAdobeClientId,
        explicitAdobeClientSecret: explicitAdobeClientSecret,
      );

      _drafts = results;
      _isProcessing = false;
      _currentStep = 3; // Review screen
      notifyListeners();
      return true;
    } catch (e) {
      _isProcessing = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void updateDraft(int index, ExtractedActivityDraft updated) {
    if (index >= 0 && index < _drafts.length) {
      _drafts[index] = updated;
      notifyListeners();
    }
  }

  void updateDraftById(String id, ExtractedActivityDraft updated) {
    final idx = _drafts.indexWhere((d) => d.id == id);
    if (idx != -1) {
      _drafts[idx] = updated;
      notifyListeners();
    }
  }

  void deleteDraft(String id) {
    _drafts.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  /// Bulk Action: Applies a recurring semester end date to all drafts.
  void bulkSetEndDate(DateTime endDate) {
    _drafts = _drafts.map((d) {
      return d.copyWith(
        recurrence: d.recurrence.copyWith(endDate: endDate),
      );
    }).toList();
    notifyListeners();
  }

  /// Bulk Action: Shifts all activity start and end timings by minutes.
  void bulkShiftTime(Duration offset) {
    _drafts = _drafts.map((d) {
      final startTotalMin = (d.startHour * 60 + d.startMinute + offset.inMinutes) % (24 * 60);
      final endTotalMin = (d.endHour * 60 + d.endMinute + offset.inMinutes) % (24 * 60);

      final newStartH = (startTotalMin >= 0 ? startTotalMin : startTotalMin + 1440) ~/ 60;
      final newStartM = (startTotalMin >= 0 ? startTotalMin : startTotalMin + 1440) % 60;
      final newEndH = (endTotalMin >= 0 ? endTotalMin : endTotalMin + 1440) ~/ 60;
      final newEndM = (endTotalMin >= 0 ? endTotalMin : endTotalMin + 1440) % 60;

      return d.copyWith(
        startHour: newStartH,
        startMinute: newStartM,
        endHour: newEndH,
        endMinute: newEndM,
      );
    }).toList();
    notifyListeners();
  }

  /// Bulk Action: Removes all incomplete / noise drafts.
  void bulkDeleteIncomplete() {
    _drafts.removeWhere((d) => d.isIncomplete);
    notifyListeners();
  }

  /// Bulk Action: Removes all noise items (low confidence or short titles).
  void bulkDeleteNoise() {
    _drafts.removeWhere((d) => d.title.trim().length < 3 || d.isIncomplete);
    notifyListeners();
  }

  /// Bulk Action: Removes all conflicting drafts.
  void bulkDeleteConflicts() {
    _drafts.removeWhere((d) => d.hasConflict);
    notifyListeners();
  }

  /// Records this import session into user history.
  Future<void> recordImportHistory({
    required String userId,
    required int activitiesCreatedCount,
    int skippedCount = 0,
    List<String> activityTitles = const [],
  }) async {
    if (historyService == null || _fileName == null) return;

    final record = PdfImportRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      filename: _fileName!,
      fileSizeBytes: _fileBytes?.length ?? 0,
      importDate: DateTime.now(),
      totalDetected: _drafts.length,
      importedCount: activitiesCreatedCount,
      skippedCount: skippedCount,
      status: activitiesCreatedCount > 0 ? 'Imported' : 'Cancelled',
      activityTitles: activityTitles.isNotEmpty
          ? activityTitles
          : _drafts.map((d) => d.title).take(10).toList(),
    );

    await historyService!.saveRecord(record);
  }

  /// Resets the wizard to initial state.
  void reset() {
    _currentStep = 0;
    _fileBytes = null;
    _fileName = null;
    _instructions = PdfImportInstructions();
    _drafts = [];
    _isProcessing = false;
    _errorMessage = null;
    _isScanned = false;
    _selectedReviewTab = 0;
    notifyListeners();
  }
}

/// Backwards compatibility alias
typedef PdfImportController = PdfImportProvider;
