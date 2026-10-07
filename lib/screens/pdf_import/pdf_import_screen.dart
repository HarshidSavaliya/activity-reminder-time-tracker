import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/database/app_database.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/adobe_pdf_service.dart';
import '../../core/services/pdf_history_service.dart';
import '../../core/services/pdf_parser_service.dart';
import '../../core/services/storage_service.dart';
import '../../models/enums/activity_source.dart';
import '../../models/extracted_activity_draft.dart';
import '../../models/pdf_import_instructions.dart';
import '../../models/pdf_import_record.dart';
import '../../providers/activity_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_snackbar.dart';
import 'widgets/adobe_pdf_embed_viewer.dart';
import 'widgets/draft_preview_list.dart';
import 'widgets/edit_draft_dialog.dart';
import 'widgets/import_history_dialog.dart';
import 'widgets/step_progress_bar.dart';

/// Wizard-based PDF Timetable Import Screen.
/// Guides users through Upload -> Instruction -> Processing -> Review -> Import.
class PdfImportScreen extends StatefulWidget {
  const PdfImportScreen({super.key});

  @override
  State<PdfImportScreen> createState() => _PdfImportScreenState();
}

class _PdfImportScreenState extends State<PdfImportScreen> {
  int _currentStep = 1;

  // Step 1: Selected File Data
  String? _selectedFileName;
  int _selectedFileSize = 0;
  Uint8List? _selectedFileBytes;
  String? _selectedSampleTemplateKey = 'cs_semester_4';
  String? _uploadError;
  String? _adobeClientId;
  String? _adobeClientSecret;
  bool _showAdobeEmbedViewer = false;

  // Step 2: Instructions
  final PdfImportInstructions _instructions = PdfImportInstructions();
  final TextEditingController _customInstructionController = TextEditingController();

  // Step 3: Processing
  String _processingStatus = 'Reading PDF document...';
  double _processingProgress = 0.2;

  // Step 4: Extracted Drafts & Review
  List<ExtractedActivityDraft> _drafts = [];

  // Step 5: Import Results
  int _importedCount = 0;
  int _skippedCount = 0;

  PdfHistoryService? _historyService;

  @override
  void initState() {
    super.initState();
    _initHistoryService();
  }

  Future<void> _initHistoryService() async {
    final prefs = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorageService(prefs);
    final adobe = AdobePdfService(storage: storage);
    if (mounted) {
      setState(() {
        _historyService = PdfHistoryService(prefs);
        _adobeClientId = adobe.getClientId();
        _adobeClientSecret = adobe.getClientSecret();
      });
    }
  }

  @override
  void dispose() {
    _customInstructionController.dispose();
    super.dispose();
  }

  // MARK: - Step 1: File Selection & Validation

  Future<void> _pickFileFromDevice() async {
    setState(() => _uploadError = null);

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (files.isEmpty) return;

      final file = files.first;
      final bytes = await file.xFile.readAsBytes();

      if (bytes.isEmpty) {
        setState(() {
          _uploadError = 'Could not read file data. Please try another PDF.';
        });
        return;
      }

      final validation = PdfParserService.validateAndExtract(
        bytes: bytes,
        filename: file.name,
      );

      if (!validation.isValid) {
        setState(() {
          _uploadError = validation.errorMessage ?? 'Invalid PDF document';
        });
        return;
      }

      setState(() {
        _selectedFileName = file.name;
        _selectedFileSize = bytes.length;
        _selectedFileBytes = bytes;
        _selectedSampleTemplateKey = null; // user uploaded custom file
        _uploadError = null;
      });
    } catch (e) {
      setState(() {
        _uploadError = 'File picker error: ${e.toString()}';
      });
    }
  }

  void _selectSampleTemplate(String key, String displayName) {
    setState(() {
      _selectedSampleTemplateKey = key;
      _selectedFileName = displayName;
      _selectedFileSize = 142 * 1024; // 142 KB simulated
      _selectedFileBytes = null;
      _uploadError = null;
    });
  }

  void _clearSelectedFile() {
    setState(() {
      _selectedFileName = null;
      _selectedFileSize = 0;
      _selectedFileBytes = null;
      _selectedSampleTemplateKey = null;
      _uploadError = null;
    });
  }

  // MARK: - Step 3: Run Processing Pipeline

  Future<void> _runExtractionPipeline() async {
    final hasAdobe = _adobeClientId != null && _adobeClientId!.trim().isNotEmpty;

    setState(() {
      _currentStep = 3;
      _processingProgress = 0.2;
      _processingStatus = (hasAdobe && _selectedFileBytes != null)
          ? 'Reading document with Adobe Sensei AI (PDF Extract API)...'
          : 'Parsing PDF document streams...';
    });

    final activityCtrl = context.read<ActivityProvider>();
    final existingActivities = activityCtrl.activities;

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _processingProgress = 0.5;
      _processingStatus = (hasAdobe && _selectedFileBytes != null)
          ? 'Extracting schedule matrix & table cells with Adobe Extract API...'
          : 'Extracting spatial coordinates and table grid...';
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _processingProgress = 0.75;
      _processingStatus = 'Reconstructing schedule matrix & checking conflicts...';
    });

    _instructions.customInstruction = _customInstructionController.text;

    List<ExtractedActivityDraft> extracted = [];

    if (_selectedFileBytes != null) {
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPreferencesStorageService(prefs);
      final adobeService = AdobePdfService(storage: storage);
      final pdfParser = PdfParserService(
        adobeService: adobeService,
      );

      try {
        extracted = await pdfParser.parseTimetable(
          pdfBytes: _selectedFileBytes!,
          filename: _selectedFileName ?? 'document.pdf',
          instructions: _instructions,
          existingActivities: existingActivities,
          explicitAdobeClientId: _adobeClientId,
          explicitAdobeClientSecret: _adobeClientSecret,
        );
      } catch (e) {
        // When PDF reading fails or is invalid, NEVER inject dummy data!
        extracted = [];
      }
    } else {
      // Demo sample template selected explicitly by user
      extracted = PdfParserService.processTimetable(
        rawText: '',
        instructions: _instructions,
        existingActivities: existingActivities,
        templateHint: _selectedSampleTemplateKey,
        isScanned: false,
      );
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _processingProgress = 1.0;
      _processingStatus = extracted.isNotEmpty
          ? 'Extraction complete! Ready for review.'
          : 'Processing complete: No timetable activities found.';
      _drafts = extracted;
      _currentStep = 4;
    });
  }

  void _showAdobeSettingsDialog() {
    final clientIdController = TextEditingController(text: _adobeClientId ?? '');
    final clientSecretController = TextEditingController(text: _adobeClientSecret ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFFA0F00)),
            SizedBox(width: 8),
            Text('Adobe Acrobat Services', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Adobe PDF Extract API uses Adobe Sensei AI to extract complex timetable structures, cells, and rows directly from scanned or vector PDFs.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clientIdController,
                decoration: const InputDecoration(
                  labelText: 'Adobe Client ID / API Key',
                  hintText: 'Enter Client ID...',
                  prefixIcon: Icon(Icons.key_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: clientSecretController,
                decoration: const InputDecoration(
                  labelText: 'Adobe Client Secret',
                  hintText: 'Enter Client Secret...',
                  prefixIcon: Icon(Icons.password_rounded, size: 20),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 10),
              const Text(
                'Get free credentials (500 free documents/month) from developer.adobe.com/console -> Acrobat Services.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newCid = clientIdController.text.trim();
              final newSec = clientSecretController.text.trim();
              final prefs = await SharedPreferences.getInstance();
              final storage = SharedPreferencesStorageService(prefs);
              final adobe = AdobePdfService(storage: storage);
              await adobe.saveCredentials(clientId: newCid, clientSecret: newSec);
              if (mounted) {
                setState(() {
                  _adobeClientId = newCid.isNotEmpty ? newCid : null;
                  _adobeClientSecret = newSec.isNotEmpty ? newSec : null;
                });
                CustomSnackbar.showSuccess(context, 'Adobe PDF Services credentials saved');
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Save Credentials'),
          ),
        ],
      ),
    );
  }



  // MARK: - Step 4: Actions in Review Screen

  void _editDraft(ExtractedActivityDraft draft) {
    showDialog(
      context: context,
      builder: (context) => EditDraftDialog(
        draft: draft,
        onSave: (updated) {
          setState(() {
            final index = _drafts.indexWhere((d) => d.id == updated.id);
            if (index != -1) {
              _drafts[index] = updated;
            }
          });
          CustomSnackbar.showSuccess(context, 'Activity updated');
        },
      ),
    );
  }

  // MARK: - Step 5: Final Import Execution

  Future<void> _importSelectedActivities() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final selected = _drafts.where((d) => d.isSelected).toList();
    final skippedDuplicates = _drafts.where((d) => !d.isSelected && d.isDuplicate).toList();

    if (selected.isEmpty) {
      CustomSnackbar.showError(context, 'Please select at least one activity to schedule');
      return;
    }

    final activityCtrl = context.read<ActivityProvider>();
    final now = DateTime.now();
    int imported = 0;

    for (final draft in selected) {
      // Calculate target start date (next upcoming occurrence of draft.weekday)
      int daysToAdd = (draft.weekday - now.weekday) % 7;
      if (daysToAdd < 0) daysToAdd += 7;
      final targetDate = now.add(Duration(days: daysToAdd));

      final startDateTime = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        draft.startHour,
        draft.startMinute,
      );

      final endDateTime = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        draft.endHour,
        draft.endMinute,
      );

      await activityCtrl.createActivity(
        userId: user.id,
        title: draft.title,
        description: draft.description,
        category: draft.category,
        date: targetDate,
        startTime: startDateTime,
        endTime: endDateTime,
        priority: draft.priority,
        location: draft.location,
        source: ActivitySource.pdf,
        recurrence: draft.recurrence,
      );
      imported++;
    }

    // Save record to PDF History
    if (_historyService != null) {
      final record = PdfImportRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.id,
        filename: _selectedFileName ?? 'Activity_Schedule.pdf',
        fileSizeBytes: _selectedFileSize,
        importDate: DateTime.now(),
        totalDetected: _drafts.length,
        importedCount: imported,
        skippedCount: skippedDuplicates.length,
        status: 'Imported',
        activityTitles: selected.map((s) => s.title).toList(),
      );
      await _historyService!.saveRecord(record);
      if (AppDatabase.instance.isOpen) {
        try {
          await AppDatabase.instance.insertPdfRecord(record);
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
      _importedCount = imported;
      _skippedCount = skippedDuplicates.length;
      _currentStep = 5;
    });
  }

  void _showImportHistory() {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null || _historyService == null) return;

    showDialog(
      context: context,
      builder: (context) => ImportHistoryDialog(
        userId: user.id,
        historyService: _historyService!,
      ),
    );
  }

  void _resetWizard() {
    setState(() {
      _currentStep = 1;
      _clearSelectedFile();
      _drafts.clear();
      _customInstructionController.clear();
      _importedCount = 0;
      _skippedCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Import PDF Timetable',
        subtitle: 'Auto-schedule activities & routines with AI',
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFFA0F00)),
            tooltip: 'Adobe PDF Services Settings',
            onPressed: _showAdobeSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Import History',
            onPressed: _showImportHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: StepProgressBar(currentStep: _currentStep),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: AppDimensions.screenPadding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
                    child: switch (_currentStep) {
                      1 => _buildStep1Upload(context),
                      2 => _buildStep2Instructions(context),
                      3 => _buildStep3Processing(context),
                      4 => _buildStep4Review(context),
                      5 => _buildStep5Complete(context),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Upload View
  Widget _buildStep1Upload(BuildContext context) {
    final theme = Theme.of(context);
    final hasFile = _selectedFileName != null;

    final hasAdobe = _adobeClientId != null && _adobeClientId!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Adobe Acrobat Services & Embed API Banner
        Container(
          margin: const EdgeInsets.only(bottom: AppDimensions.space8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFA0F00).withValues(alpha: 0.08),
            borderRadius: AppDimensions.borderRadiusMd,
            border: Border.all(
              color: const Color(0xFFFA0F00).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFFA0F00), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasAdobe
                          ? 'Adobe Acrobat Services: Connected'
                          : 'Adobe PDF Extract & Embed API',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      hasAdobe
                          ? 'Sensei AI table recognition & PDF Embed viewer active'
                          : 'Configure Adobe Client ID for high-accuracy table & schedule extraction',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _showAdobeSettingsDialog,
                child: Text(
                  hasAdobe ? 'Configured' : 'Configure',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),


        InkWell(
          onTap: _pickFileFromDevice,
          borderRadius: AppDimensions.borderRadiusMd,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: AppDimensions.borderRadiusMd,
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.upload_file_rounded,
                    size: 36,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Upload PDF Timetable',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select your college routine, semester timetable, or test schedule',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickFileFromDevice,
                  icon: const Icon(Icons.file_open_rounded, size: 18),
                  label: const Text('Choose PDF from Device'),
                ),
              ],
            ),
          ),
        ),

        // Error message banner
        if (_uploadError != null) ...[
          const SizedBox(height: AppDimensions.space12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: AppDimensions.borderRadiusSm,
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _uploadError!,
                    style: const TextStyle(fontSize: 12, color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Selected File Card
        if (hasFile) ...[
          const SizedBox(height: AppDimensions.space16),
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 32),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedFileName!,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Size: ${(_selectedFileSize / 1024).toStringAsFixed(1)} KB • Ready for extraction',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Remove',
                  onPressed: _clearSelectedFile,
                ),
              ],
            ),
          ),
          if (_selectedFileBytes != null) ...[
            const SizedBox(height: AppDimensions.space8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showAdobeEmbedViewer = !_showAdobeEmbedViewer),
                icon: Icon(
                  _showAdobeEmbedViewer ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 16,
                  color: const Color(0xFFFA0F00),
                ),
                label: Text(
                  _showAdobeEmbedViewer ? 'Hide PDF Preview' : 'Preview Document (Adobe PDF Embed)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (_showAdobeEmbedViewer) ...[
              const SizedBox(height: 8),
              AdobePdfEmbedViewer(
                pdfBytes: _selectedFileBytes,
                fileName: _selectedFileName ?? 'document.pdf',
                fileSizeBytes: _selectedFileSize,
                adobeClientId: _adobeClientId,
                onConfigureAdobe: _showAdobeSettingsDialog,
                onClose: () => setState(() => _showAdobeEmbedViewer = false),
              ),
            ],
          ],
        ],

        const SizedBox(height: AppDimensions.space24),

        // Sample Timetables for Instant Testing
        Text(
          'Or Try a Sample Routine or Timetable',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: AppDimensions.space8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSampleChip(
              key: 'weekly_work',
              title: 'Weekly Work & Routine Schedule',
              subtitle: 'Standups, workouts & focus blocks',
            ),
            _buildSampleChip(
              key: 'cs_semester_4',
              title: 'Semester 4 Computer Engineering',
              subtitle: '8 lectures & labs',
            ),
            _buildSampleChip(
              key: 'exam_schedule',
              title: 'Midterm Examination Schedule',
              subtitle: '3 high-priority exams',
            ),
          ],
        ),

        const SizedBox(height: AppDimensions.space32),

        AppButton(
          text: 'Continue to Instructions →',
          icon: Icons.arrow_forward_rounded,
          onPressed: hasFile ? () => setState(() => _currentStep = 2) : null,
        ),
      ],
    );
  }

  Widget _buildSampleChip({
    required String key,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedSampleTemplateKey == key;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _selectSampleTemplate(key, title),
      borderRadius: AppDimensions.borderRadiusSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: AppDimensions.borderRadiusSm,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.description_outlined,
              size: 16,
              color: isSelected ? theme.colorScheme.primary : null,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 2. Instructions View
  Widget _buildStep2Instructions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What information should we read from this PDF?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Customize filters so only your relevant lectures and sections are parsed into your schedule.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Divider(height: 24),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Subject Name', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Reads course title or subject name', style: TextStyle(fontSize: 11)),
                  value: _instructions.readSubjectName,
                  onChanged: (v) => setState(() => _instructions.readSubjectName = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start Time', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Reads activity starting times', style: TextStyle(fontSize: 11)),
                  value: _instructions.readStartTime,
                  onChanged: (v) => setState(() => _instructions.readStartTime = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('End Time', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Reads activity ending times', style: TextStyle(fontSize: 11)),
                  value: _instructions.readEndTime,
                  onChanged: (v) => setState(() => _instructions.readEndTime = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Classroom / Hall', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Detects room or laboratory location codes', style: TextStyle(fontSize: 11)),
                  value: _instructions.readClassroom,
                  onChanged: (v) => setState(() => _instructions.readClassroom = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Extract Exams & Midterms', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Tags test dates with High Priority badge', style: TextStyle(fontSize: 11)),
                  value: _instructions.extractExams,
                  onChanged: (v) => setState(() => _instructions.extractExams = v),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _customInstructionController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Instruction / Section Filter (Optional)',
                    hintText: 'e.g. "Only extract Division B" or "Ignore Wednesday sports"',
                    prefixIcon: Icon(Icons.tune_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.space24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = 1),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: AppButton(
                text: 'Extract Activities →',
                icon: Icons.auto_awesome_rounded,
                onPressed: _runExtractionPipeline,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 3. Processing View
  Widget _buildStep3Processing(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          CircularProgressIndicator(value: _processingProgress),
          const SizedBox(height: 24),
          Text(
            _processingStatus,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            'Analyzing spatial bounding boxes, row alignments, and room codes...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Review View (3 Actionable Tabs + Bulk Tools)
  Widget _buildStep4Review(BuildContext context) {
    final theme = Theme.of(context);
    final hasDrafts = _drafts.isNotEmpty;

    if (!hasDrafts) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: AppDimensions.borderRadiusMd,
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.search_off_rounded, size: 40, color: Colors.amber),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Activities Detected in PDF',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'We could not extract any readable timetable activities or schedule tables from this document.\n'
                  'To protect your schedule integrity, NO dummy or fake data has been added.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: AppDimensions.borderRadiusSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💡 Recommendations for reading your schedule:',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• Ensure the PDF contains readable text with day headers (e.g. Monday) and time intervals (e.g. 09:00 AM - 10:30 AM).\n'
                        '• If your PDF is an image scan, photograph, or complex table, configure Adobe PDF Services (Extract API) via the top settings.\n'
                        '• Verify the document is not password-protected or encrypted.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _currentStep = 1),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Try Another PDF'),
                ),
              ),
              const SizedBox(width: AppDimensions.space12),
              Expanded(
                child: AppButton(
                  text: 'Configure Adobe / AI',
                  icon: Icons.settings_rounded,
                  onPressed: _showAdobeSettingsDialog,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space32),
        ],
      );
    }

    final selectedCount = _drafts.where((d) => d.isSelected).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DraftPreviewList(
          drafts: _drafts,
          onDraftsUpdated: (updated) => setState(() => _drafts = updated),
          onEditDraft: _editDraft,
        ),

        const SizedBox(height: AppDimensions.space24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = 2),
                child: const Text('Back to Options'),
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: AppButton(
                text: selectedCount > 0
                    ? 'Schedule $selectedCount Activities →'
                    : 'Select Activities to Schedule',
                icon: Icons.check_circle_rounded,
                onPressed: selectedCount > 0 ? _importSelectedActivities : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space32),
      ],
    );
  }

  // 5. Completion View
  Widget _buildStep5Complete(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: AppDimensions.borderRadiusLg,
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Timetable Scheduled Successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '$_importedCount activities have been added to your routines and calendar.'
                '${_skippedCount > 0 ? " $_skippedCount duplicate entries were excluded." : ""}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.space24),
        AppButton(
          text: 'View in Calendar & Dashboard',
          icon: Icons.calendar_month_rounded,
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
          },
        ),
        const SizedBox(height: AppDimensions.space12),
        OutlinedButton(
          onPressed: _resetWizard,
          child: const Text('Import Another PDF'),
        ),
      ],
    );
  }
}
