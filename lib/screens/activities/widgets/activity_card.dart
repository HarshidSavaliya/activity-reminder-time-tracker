import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../models/activity_model.dart';
import '../../../models/enums/activity_category.dart';
import '../../../models/enums/activity_status.dart';
import '../../../providers/activity_provider.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/confirmation_dialog.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../widgets/priority_badge.dart';
import 'reschedule_dialog.dart';

/// ActivityCard provides rich visual metadata and gestures:
/// - Tap: View details
/// - Checkbox: Mark Complete / Pending with Undo SnackBar
/// - Swipe Right: Mark Complete with Undo
/// - Swipe Left: Delete with Undo
/// - Long Press: Quick action sheet (Reschedule, Edit, Delete, Skip)
/// - Pairs priority and category badges with distinct icons for color-blind accessibility
/// - Adapts dynamically with MediaQuery.textScalerOf(context)
class ActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final String userId;
  final ActivityProvider activityCtrl;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.userId,
    required this.activityCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDone = activity.isCompleted;
    final isMissed = activity.isOverdue;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space8),
      child: Dismissible(
        key: Key('activity_${activity.id}_${activity.occurrenceDate?.toIso8601String() ?? ""}'),
        direction: DismissDirection.horizontal,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: AppDimensions.borderRadiusMd,
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Complete',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: AppDimensions.borderRadiusMd,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Delete',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              SizedBox(width: 8),
              Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            // Swipe Right -> Mark Complete / Pending with Undo
            final parentId = activity.recurrenceParentId ?? activity.id;
            final occurrenceDate = activity.occurrenceDate;
            await activityCtrl.toggleCompletion(
              userId,
              parentId,
              occurrenceDate: occurrenceDate,
            );

            if (context.mounted) {
              CustomSnackbar.showAction(
                context,
                message: isDone
                    ? '"${activity.title}" marked as pending'
                    : '"${activity.title}" marked as complete',
                actionLabel: 'Undo',
                onAction: () {
                  activityCtrl.toggleCompletion(
                    userId,
                    parentId,
                    occurrenceDate: occurrenceDate,
                  );
                },
              );
            }
            return false; // Don't remove from widget tree
          } else {
            // Swipe Left -> Delete with Undo
            if (activity.isRecurring) {
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

              if (choice == 'occurrence') {
                await activityCtrl.deleteOccurrence(
                  userId,
                  activity.recurrenceParentId ?? activity.id,
                  activity.occurrenceDate ?? activity.date,
                );
                return true;
              } else if (choice == 'series') {
                final backup = activity;
                await activityCtrl.deleteActivity(userId, activity.recurrenceParentId ?? activity.id);
                if (context.mounted) _showUndoDeleteSnackbar(context, backup);
                return true;
              }
              return false;
            } else {
              final backup = activity;
              await activityCtrl.deleteActivity(userId, activity.id);
              if (context.mounted) _showUndoDeleteSnackbar(context, backup);
              return true;
            }
          }
        },
        child: AppCard(
          onTap: () {
            Navigator.of(context).pushNamed(
              AppRoutes.activityDetail,
              arguments: activity,
            );
          },
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space12,
            vertical: AppDimensions.space12,
          ),
          backgroundColor: isDone
              ? (isDark ? const Color(0xFF16181F) : const Color(0xFFF1F3F5))
              : (isMissed
                  ? (isDark
                      ? AppColors.priorityHighBgDark.withValues(alpha: 0.5)
                      : AppColors.priorityHighBg.withValues(alpha: 0.4))
                  : null),
          borderColor: isMissed
              ? AppColors.priorityHigh.withValues(alpha: 0.4)
              : null,
          child: InkWell(
            onLongPress: () => _showQuickActionSheet(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Completion Toggle Checkbox
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : (isMissed
                            ? Icons.error_outline_rounded
                            : Icons.radio_button_unchecked_rounded),
                    color: isDone
                        ? AppColors.success
                        : (isMissed
                            ? AppColors.priorityHigh
                            : theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                    size: 22,
                  ),
                  onPressed: () {
                    final parentId = activity.recurrenceParentId ?? activity.id;
                    final occurrenceDate = activity.occurrenceDate;
                    activityCtrl.toggleCompletion(
                      userId,
                      parentId,
                      occurrenceDate: occurrenceDate,
                    );

                    CustomSnackbar.showAction(
                      context,
                      message: isDone
                          ? '"${activity.title}" marked as pending'
                          : '"${activity.title}" marked as complete',
                      actionLabel: 'Undo',
                      onAction: () {
                        activityCtrl.toggleCompletion(
                          userId,
                          parentId,
                          occurrenceDate: occurrenceDate,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(width: AppDimensions.space8),

                // Main Details with Dynamic Text Scaling
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              activity.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isDone ? FontWeight.w500 : FontWeight.w600,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                                color: isDone
                                    ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (activity.isRecurring) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.repeat_rounded,
                              size: 14,
                              color: theme.colorScheme.primary.withValues(alpha: 0.7),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppDimensions.space2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Text(
                            DateTimeUtils.formatTimeRange(activity.startTime, activity.endTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDone
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                  : (isMissed
                                      ? AppColors.priorityHigh
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.65)),
                            ),
                          ),
                          if (activity.location.isNotEmpty) ...[
                            Text(
                              '•',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                            Text(
                              activity.location,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDone
                                    ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.space8),

                // Category & Priority Badges (both paired with distinct icons for color-blind accessibility)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PriorityBadge(priority: activity.priority),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: activity.category.color.withValues(alpha: 0.12),
                        borderRadius: AppDimensions.borderRadiusSm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(activity.category.icon, size: 10, color: activity.category.color),
                          const SizedBox(width: 3),
                          Text(
                            activity.category.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: activity.category.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUndoDeleteSnackbar(BuildContext context, ActivityModel deletedItem) {
    CustomSnackbar.showAction(
      context,
      message: 'Deleted "${deletedItem.title}"',
      actionLabel: 'Undo',
      onAction: () {
        activityCtrl.createActivity(
          userId: deletedItem.userId,
          title: deletedItem.title,
          description: deletedItem.description,
          category: deletedItem.category,
          date: deletedItem.date,
          startTime: deletedItem.startTime,
          endTime: deletedItem.endTime,
          priority: deletedItem.priority,
          status: deletedItem.status,
          reminder: deletedItem.reminder,
          recurrence: deletedItem.recurrence,
          location: deletedItem.location,
          source: deletedItem.source,
        );
      },
    );
  }

  void _showQuickActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: AppDimensions.padding16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppDimensions.space12),
                ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('Reschedule Activity'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    final res = await RescheduleDialog.show(context, activity);
                    if (res != null) {
                      await activityCtrl.rescheduleActivity(
                        userId,
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
                ListTile(
                  leading: Icon(
                    activity.isCompleted ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                  ),
                  title: Text(
                    activity.isCompleted ? 'Mark as Pending' : 'Mark as Completed',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    final parentId = activity.recurrenceParentId ?? activity.id;
                    final occurrenceDate = activity.occurrenceDate;
                    activityCtrl.toggleCompletion(
                      userId,
                      parentId,
                      occurrenceDate: occurrenceDate,
                    );
                    CustomSnackbar.showAction(
                      context,
                      message: activity.isCompleted
                          ? 'Marked "${activity.title}" as pending'
                          : 'Marked "${activity.title}" as complete',
                      actionLabel: 'Undo',
                      onAction: () {
                        activityCtrl.toggleCompletion(
                          userId,
                          parentId,
                          occurrenceDate: occurrenceDate,
                        );
                      },
                    );
                  },
                ),
                if (activity.isOverdue)
                  ListTile(
                    leading: const Icon(Icons.redo_rounded, color: AppColors.warning),
                    title: const Text('Skip Missed Activity'),
                    onTap: () {
                      Navigator.of(context).pop();
                      activityCtrl.markStatus(
                        userId,
                        activity.recurrenceParentId ?? activity.id,
                        ActivityStatus.skipped,
                        occurrenceDate: activity.occurrenceDate,
                      );
                      CustomSnackbar.showInfo(context, 'Activity marked as skipped');
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit Activity'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamed(
                      AppRoutes.activityForm,
                      arguments: activity,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  title: const Text('Delete Activity', style: TextStyle(color: AppColors.error)),
                  onTap: () async {
                    Navigator.of(context).pop();
                    final confirmed = await ConfirmationDialog.show(
                      context,
                      title: 'Delete Activity',
                      message: 'Are you sure you want to delete "${activity.title}"?',
                      confirmText: 'Delete',
                      isDestructive: true,
                    );
                    if (confirmed == true) {
                      final backup = activity;
                      activityCtrl.deleteActivity(
                        userId,
                        activity.recurrenceParentId ?? activity.id,
                      );
                      if (context.mounted) _showUndoDeleteSnackbar(context, backup);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
