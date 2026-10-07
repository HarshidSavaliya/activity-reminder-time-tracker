import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/database/app_database.dart';
import '../../../widgets/app_button.dart';

class DatabaseInfoDialog extends StatelessWidget {
  final Map<String, int> stats;

  const DatabaseInfoDialog({super.key, required this.stats});

  static Future<void> show(BuildContext context) async {
    final stats = await AppDatabase.instance.getStats();
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => DatabaseInfoDialog(stats: stats),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppDimensions.borderRadiusLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: AppDimensions.padding24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.storage_rounded, color: AppColors.secondary, size: 22),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SQLite Local Storage',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Relational On-Device Database',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: AppDimensions.borderRadiusMd,
                ),
                child: Column(
                  children: [
                    _buildStatRow('Status', 'Connected / Active', isGood: true),
                    const Divider(height: 16),
                    _buildStatRow('Database File', 'activity_reminder_tracker.db'),
                    const Divider(height: 16),
                    _buildStatRow('Activities Stored', '${stats['activities'] ?? 0} records'),
                    const Divider(height: 16),
                    _buildStatRow('PDF Import Logs', '${stats['pdf_imports'] ?? 0} batches'),
                    const Divider(height: 16),
                    _buildStatRow('User Accounts', '${stats['users'] ?? 0} active'),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.space16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All your routines, activities, and settings persist securely and completely offline on your device.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space20),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  text: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {bool isGood = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isGood) ...[
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 6),
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isGood ? AppColors.success : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
