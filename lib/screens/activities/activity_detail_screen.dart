import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/date_time_utils.dart';
import '../../models/activity_model.dart';
import '../../models/enums/activity_category.dart';
import '../../models/enums/activity_source.dart';
import '../../models/enums/activity_status.dart';
import '../../providers/activity_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/priority_badge.dart';
import 'widgets/reschedule_dialog.dart';

/// ActivityDetailScreen displays comprehensive activity metadata, occurrence details,
/// and full lifecycle controls (Reschedule, Mark Complete with Undo, Skip, Edit, and Delete with Undo).
class ActivityDetailScreen extends StatelessWidget {
  final ActivityModel activity;

  const ActivityDetailScreen({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final activityCtrl = context.watch<ActivityProvider>();
    final user = auth.currentUser;

    final current = activityCtrl.activities.firstWhere(
      (a) => a.id == (activity.recurrenceParentId ?? activity.id),
      orElse: () => activity,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Details'),
        actions: [
          IconButton(
            tooltip: 'Reschedule',
            icon: const Icon(Icons.edit_calendar_rounded),
            onPressed: () async {
              final res = await RescheduleDialog.show(context, activity);
              if (res != null && user != null) {
                await activityCtrl.rescheduleActivity(
                  user.id,
                  activity.recurrenceParentId ?? activity.id,
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
          IconButton(
            tooltip: 'Edit Activity',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed(
                AppRoutes.activityForm,
                arguments: activity,
              );
            },
          ),
          IconButton(
            tooltip: 'Delete Activity',
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: () async {
              if (activity.isRecurring && user != null) {
                final choice = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Recurring Activity'),
                    content: const Text(
                        'Do you want to delete only this occurrence or the entire recurring series?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop('cancel'),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop('occurrence'),
                        child: const Text('This occurrence only'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop('series'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                        child: const Text('Entire series'),
                      ),
                    ],
                  ),
                );

                if (choice == 'occurrence' && context.mounted) {
                  await activityCtrl.deleteOccurrence(
                    user.id,
                    activity.recurrenceParentId ?? activity.id,
                    activity.occurrenceDate ?? activity.date,
                  );
                  if (context.mounted) {
                    CustomSnackbar.showInfo(context, 'Occurrence deleted');
                    Navigator.of(context).pop();
                  }
                } else if (choice == 'series' && context.mounted) {
                  final backup = activity;
                  await activityCtrl.deleteActivity(user.id, activity.recurrenceParentId ?? activity.id);
                  if (context.mounted) {
                    CustomSnackbar.showAction(
                      context,
                      message: 'Entire series deleted',
                      actionLabel: 'Undo',
                      onAction: () {
                        activityCtrl.createActivity(
                          userId: backup.userId,
                          title: backup.title,
                          description: backup.description,
                          category: backup.category,
                          date: backup.date,
                          startTime: backup.startTime,
                          endTime: backup.endTime,
                          priority: backup.priority,
                          status: backup.status,
                          reminder: backup.reminder,
                          recurrence: backup.recurrence,
                          location: backup.location,
                          source: backup.source,
                        );
                      },
                    );
                    Navigator.of(context).pop();
                  }
                }
              } else if (user != null) {
                final confirmed = await ConfirmationDialog.show(
                  context,
                  title: 'Delete Activity',
                  message: 'Are you sure you want to delete "${activity.title}"?',
                  confirmText: 'Delete',
                  isDestructive: true,
                );

                if (confirmed == true && context.mounted) {
                  final backup = activity;
                  await activityCtrl.deleteActivity(user.id, activity.id);
                  if (context.mounted) {
                    CustomSnackbar.showAction(
                      context,
                      message: 'Activity deleted',
                      actionLabel: 'Undo',
                      onAction: () {
                        activityCtrl.createActivity(
                          userId: backup.userId,
                          title: backup.title,
                          description: backup.description,
                          category: backup.category,
                          date: backup.date,
                          startTime: backup.startTime,
                          endTime: backup.endTime,
                          priority: backup.priority,
                          status: backup.status,
                          reminder: backup.reminder,
                          recurrence: backup.recurrence,
                          location: backup.location,
                          source: backup.source,
                        );
                      },
                    );
                    Navigator.of(context).pop();
                  }
                }
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppDimensions.screenPadding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Main Detail Card
                  AppCard(
                    padding: AppDimensions.padding20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: activity.category.color.withValues(alpha: 0.15),
                                borderRadius: AppDimensions.borderRadiusSm,
                              ),
                              child: Icon(
                                activity.category.icon,
                                color: activity.category.color,
                                size: 24,
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
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: AppDimensions.space4),
                                  Row(
                                    children: [
                                      Text(
                                        activity.category.displayName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: activity.category.color,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: activity.status.color.withValues(alpha: 0.15),
                                          borderRadius: AppDimensions.borderRadiusSm,
                                        ),
                                        child: Text(
                                          activity.status.displayName,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: activity.status.color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            PriorityBadge(priority: activity.priority),
                          ],
                        ),
                        if (activity.description.isNotEmpty) ...[
                          const SizedBox(height: AppDimensions.space16),
                          Text(
                            activity.description,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space16),

                  // Schedule Info Card
                  AppCard(
                    child: Column(
                      children: [
                        _buildInfoRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Scheduled Date',
                          value: DateTimeUtils.formatFullDate(activity.occurrenceDate ?? activity.date),
                          theme: theme,
                        ),
                        const Divider(height: 20),
                        _buildInfoRow(
                          icon: Icons.access_time_rounded,
                          label: 'Time Range',
                          value: DateTimeUtils.formatTimeRange(activity.startTime, activity.endTime),
                          theme: theme,
                        ),
                        if (activity.location.isNotEmpty) ...[
                          const Divider(height: 20),
                          _buildInfoRow(
                            icon: Icons.place_outlined,
                            label: 'Location / Venue',
                            value: activity.location,
                            theme: theme,
                          ),
                        ],
                        const Divider(height: 20),
                        _buildInfoRow(
                          icon: Icons.notifications_active_outlined,
                          label: 'Reminder Alert',
                          value: activity.reminder.label,
                          theme: theme,
                        ),
                        const Divider(height: 20),
                        _buildInfoRow(
                          icon: Icons.repeat_rounded,
                          label: 'Recurrence Pattern',
                          value: current.recurrence.summary,
                          theme: theme,
                        ),
                        const Divider(height: 20),
                        _buildInfoRow(
                          icon: activity.source.icon,
                          label: 'Source',
                          value: activity.source.displayName,
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space24),

                  // Actions with Undo SnackBar
                  AppButton(
                    text: activity.isCompleted ? 'Mark as Pending' : 'Mark as Completed',
                    icon: activity.isCompleted
                        ? Icons.remove_done_rounded
                        : Icons.check_circle_outline_rounded,
                    variant: activity.isCompleted
                        ? AppButtonVariant.outlined
                        : AppButtonVariant.primary,
                    onPressed: () {
                      if (user != null) {
                        final parentId = activity.recurrenceParentId ?? activity.id;
                        final occurrenceDate = activity.occurrenceDate;
                        activityCtrl.toggleCompletion(
                          user.id,
                          parentId,
                          occurrenceDate: occurrenceDate,
                        );
                        CustomSnackbar.showAction(
                          context,
                          message: activity.isCompleted
                              ? 'Moved to pending'
                              : 'Marked as completed! Great job.',
                          actionLabel: 'Undo',
                          onAction: () {
                            activityCtrl.toggleCompletion(
                              user.id,
                              parentId,
                              occurrenceDate: occurrenceDate,
                            );
                          },
                        );
                      }
                    },
                  ),
                  const SizedBox(height: AppDimensions.space12),

                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_calendar_rounded),
                    label: const Text('Reschedule Activity'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
                    ),
                    onPressed: () async {
                      final res = await RescheduleDialog.show(context, activity);
                      if (res != null && user != null) {
                        await activityCtrl.rescheduleActivity(
                          user.id,
                          activity.recurrenceParentId ?? activity.id,
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
                  const SizedBox(height: AppDimensions.space32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppDimensions.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
