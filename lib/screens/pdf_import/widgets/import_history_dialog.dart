import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/services/pdf_history_service.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../models/pdf_import_record.dart';

/// Modal dialog showing the user's historical PDF schedule imports.
class ImportHistoryDialog extends StatefulWidget {
  final String userId;
  final PdfHistoryService historyService;

  const ImportHistoryDialog({
    super.key,
    required this.userId,
    required this.historyService,
  });

  @override
  State<ImportHistoryDialog> createState() => _ImportHistoryDialogState();
}

class _ImportHistoryDialogState extends State<ImportHistoryDialog> {
  late List<PdfImportRecord> _records;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  void _loadRecords() {
    setState(() {
      _records = widget.historyService.getRecords(widget.userId);
    });
  }

  Future<void> _deleteRecord(String recordId) async {
    await widget.historyService.deleteRecord(recordId, widget.userId);
    _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppDimensions.borderRadiusMd),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: AppDimensions.borderRadiusSm,
                    ),
                    child: Icon(
                      Icons.history_edu_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  const Expanded(
                    child: Text(
                      'PDF Import History',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: _records.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open_rounded,
                              size: 48,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No import history yet',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'When you import schedules from PDF documents, your history will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _records.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final rec = _records[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: AppDimensions.borderRadiusSm,
                              border: Border.all(
                                color: theme.colorScheme.outline.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: AppColors.error,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        rec.fileName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Imported on ${DateTimeUtils.formatDate(rec.timestamp)} • ${rec.importedCount} activities',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                  color: AppColors.error,
                                  tooltip: 'Delete Log',
                                  onPressed: () => _deleteRecord(rec.id),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: AppDimensions.space12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
