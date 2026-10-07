import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../models/activity_model.dart';
import '../../../models/enums/activity_status.dart';
import '../../../providers/activity_provider.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../activities/widgets/reschedule_dialog.dart';

/// MissedActivitiesSection highlights overdue tasks and presents the requested 3 actions:
/// - Complete (with Undo SnackBar)
/// - Reschedule
/// - Skip (with Undo SnackBar)
class MissedActivitiesSection extends StatelessWidget {
  final List<ActivityModel> overdueActivities;
  final String userId;
  final ActivityProvider activityCtrl;

  const MissedActivitiesSection({
    super.key,
    required this.overdueActivities,
    required this.userId,
    required this.activityCtrl,
  });

  @override
  Widget build(BuildContext context) {
    if (overdueActivities.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
            const SizedBox(width: AppDimensions.space8),
            Text(
              'MISSED ACTIVITIES (${overdueActivities.length})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space8),
        ...overdueActivities.map((activity) {
          final targetId = activity.recurrenceParentId ?? activity.id;
          final prevStatus = activity.status;

          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.space8),
            child: AppCard(
              borderColor: AppColors.error.withValues(alpha: 0.35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.priorityHigh.withValues(alpha: 0.12),
                          borderRadius: AppDimensions.borderRadiusSm,
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: AppColors.priorityHigh,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Missed • Scheduled for ${DateTimeUtils.formatDate(activity.date)} at ${DateTimeUtils.formatTime(activity.startTime)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  const Divider(height: 1),
                  const SizedBox(height: AppDimensions.space8),

                  // The 3 user actions: Complete, Reschedule, Skip
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppDimensions.space8,
                    runSpacing: AppDimensions.space4,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.redo_rounded, size: 16),
                        label: const Text('Skip'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          activityCtrl.markStatus(
                            userId,
                            targetId,
                            ActivityStatus.skipped,
                            occurrenceDate: activity.occurrenceDate,
                          );
                          CustomSnackbar.showAction(
                            context,
                            message: 'Activity marked as skipped',
                            actionLabel: 'UNDO',
                            onAction: () {
                              activityCtrl.markStatus(
                                userId,
                                targetId,
                                prevStatus,
                                occurrenceDate: activity.occurrenceDate,
                              );
                            },
                          );
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                        label: const Text('Reschedule'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          final res = await RescheduleDialog.show(context, activity);
                          if (res != null) {
                            await activityCtrl.rescheduleActivity(
                              userId,
                              targetId,
                              res['date'] as DateTime,
                              res['startTime'] as DateTime,
                              res['endTime'] as DateTime?,
                              occurrenceDate: activity.occurrenceDate,
                            );
                            if (context.mounted) {
                              CustomSnackbar.showSuccess(context, 'Activity rescheduled');
                            }
                          }
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Complete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          activityCtrl.markStatus(
                            userId,
                            targetId,
                            ActivityStatus.completed,
                            occurrenceDate: activity.occurrenceDate,
                          );
                          CustomSnackbar.showAction(
                            context,
                            message: 'Marked as completed!',
                            actionLabel: 'UNDO',
                            onAction: () {
                              activityCtrl.markStatus(
                                userId,
                                targetId,
                                prevStatus,
                                occurrenceDate: activity.occurrenceDate,
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: AppDimensions.space16),
      ],
    );
  }
}
