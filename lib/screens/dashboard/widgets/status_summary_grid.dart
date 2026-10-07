import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';

/// StatusSummaryGrid replicates the 2x2 colorful pill status cards from reference Image 1:
/// - Purple: "To do list"
/// - Yellow/Amber: "In progress"
/// - Pink: "In review"
/// - Green: "Complete"
class StatusSummaryGrid extends StatelessWidget {
  final int totalCount;
  final int pendingCount;
  final int inReviewCount;
  final int completedCount;
  final ValueChanged<int>? onCardTapped; // 0: All/Todo, 1: Pending, 2: Review, 3: Completed

  const StatusSummaryGrid({
    super.key,
    required this.totalCount,
    required this.pendingCount,
    required this.inReviewCount,
    required this.completedCount,
    this.onCardTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            // Top-Left: Purple "To do list" Card
            Expanded(
              child: _buildStatusCard(
                color: AppColors.statusTodo,
                icon: Icons.assignment_outlined,
                iconBg: Colors.white.withValues(alpha: 0.22),
                iconColor: Colors.white,
                title: 'To do list',
                titleColor: Colors.white,
                count: '$totalCount tasks',
                countColor: Colors.white.withValues(alpha: 0.95),
                onTap: () => onCardTapped?.call(0),
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            // Top-Right: Warm Amber "In progress" Card
            Expanded(
              child: _buildStatusCard(
                color: AppColors.statusInProgress,
                icon: Icons.timelapse_rounded,
                iconBg: Colors.white.withValues(alpha: 0.35),
                iconColor: const Color(0xFF451A03),
                title: 'In progress',
                titleColor: const Color(0xFF451A03),
                count: '$pendingCount tasks',
                countColor: const Color(0xFF78350F),
                onTap: () => onCardTapped?.call(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space12),
        Row(
          children: [
            // Bottom-Left: Soft Pink "In review" Card
            Expanded(
              child: _buildStatusCard(
                color: AppColors.statusInReview,
                icon: Icons.flag_rounded,
                iconBg: Colors.white.withValues(alpha: 0.4),
                iconColor: const Color(0xFF701A75),
                title: 'In review',
                titleColor: const Color(0xFF701A75),
                count: '$inReviewCount tasks',
                countColor: const Color(0xFF86198F),
                onTap: () => onCardTapped?.call(2),
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            // Bottom-Right: Fresh Emerald "Complete" Card
            Expanded(
              child: _buildStatusCard(
                color: AppColors.statusComplete,
                icon: Icons.check_circle_outline_rounded,
                iconBg: Colors.white.withValues(alpha: 0.22),
                iconColor: Colors.white,
                title: 'Complete',
                titleColor: Colors.white,
                count: '$completedCount tasks',
                countColor: Colors.white.withValues(alpha: 0.95),
                onTap: () => onCardTapped?.call(3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required Color color,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required Color titleColor,
    required String count,
    required Color countColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: iconColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                count,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: countColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
