import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../models/activity_model.dart';
import '../../../models/enums/activity_category.dart';

/// HeroActivityCard replicates the purple highlighted task card from Image 1:
/// - Purple background (#8B5CF6)
/// - White title and white badges ("High", "On Track" / Category)
/// - Time, date, and room metadata
/// - Trailing more options button
class HeroActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;

  const HeroActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
    required this.onToggleComplete,
  });

  @override
  Widget build(BuildContext context) {
    final startTimeStr = DateTimeUtils.formatTimeOfDay(
      TimeOfDay.fromDateTime(activity.startTime),
    );
    final endTimeStr = activity.endTime != null
        ? DateTimeUtils.formatTimeOfDay(TimeOfDay.fromDateTime(activity.endTime!))
        : null;

    final dateStr = DateTimeUtils.formatShortDate(activity.date);

    return Material(
      color: AppColors.statusTodo,
      borderRadius: BorderRadius.circular(22),
      elevation: 2,
      shadowColor: AppColors.statusTodo.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Title and ... more button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      activity.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: onToggleComplete,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        activity.isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.check_circle_outline_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // White Badges: Priority ("High"), Category / "On Track"
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildWhitePill(
                    activity.priority.name[0].toUpperCase() +
                        activity.priority.name.substring(1),
                    isPriority: true,
                  ),
                  _buildWhitePill(
                    activity.category.displayName,
                    isPriority: false,
                  ),
                  if (activity.location.isNotEmpty)
                    _buildWhitePill(
                      activity.location,
                      icon: Icons.meeting_room_outlined,
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Bottom Meta Row: Date, Time range, and Room
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white70),
                  const SizedBox(width: 5),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.access_time_rounded, size: 14, color: Colors.white70),
                  const SizedBox(width: 5),
                  Text(
                    endTimeStr != null ? '$startTimeStr - $endTimeStr' : startTimeStr,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          activity.isCompleted
                              ? Icons.check_circle_outline_rounded
                              : Icons.schedule_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          activity.isCompleted ? 'Completed' : 'Upcoming',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
    );
  }

  Widget _buildWhitePill(String text, {bool isPriority = false, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppColors.statusTodo),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isPriority ? const Color(0xFFE11D48) : AppColors.statusTodo,
            ),
          ),
        ],
      ),
    );
  }
}
