import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/activity_provider.dart';
import '../../../widgets/app_card.dart';

/// TaskStatisticsChart displays dynamic multi-line spline curves driven by real user activities:
/// - Progress (Pending/Ongoing tasks)
/// - Review (High-priority/Study tasks)
/// - Complete (Finished tasks)
/// - Fully dynamic Y-axis scale based on current weekly workload
class TaskStatisticsChart extends StatelessWidget {
  final List<double>? progressData;
  final List<double>? reviewData;
  final List<double>? completeData;
  final double? customMaxY;

  const TaskStatisticsChart({
    super.key,
    this.progressData,
    this.reviewData,
    this.completeData,
    this.customMaxY,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    WeeklyActivityStats? dynamicStats;
    try {
      final activityCtrl = context.watch<ActivityProvider>();
      dynamicStats = activityCtrl.getWeeklyStats();
    } catch (_) {}

    final progress = progressData ?? dynamicStats?.progress ?? const [0, 0, 0, 0, 0, 0, 0];
    final review = reviewData ?? dynamicStats?.review ?? const [0, 0, 0, 0, 0, 0, 0];
    final complete = completeData ?? dynamicStats?.complete ?? const [0, 0, 0, 0, 0, 0, 0];
    final effectiveMaxY = customMaxY ?? dynamicStats?.maxY ?? 5.0;

    final totalProgress = progress.fold<double>(0, (sum, val) => sum + val).toInt();
    final totalReview = review.fold<double>(0, (sum, val) => sum + val).toInt();
    final totalComplete = complete.fold<double>(0, (sum, val) => sum + val).toInt();

    // 5 dynamic Y-axis tick values from maxY down to 0
    final yTicks = [
      effectiveMaxY.toInt().toString(),
      (effectiveMaxY * 0.8).round().toString(),
      (effectiveMaxY * 0.6).round().toString(),
      (effectiveMaxY * 0.4).round().toString(),
      (effectiveMaxY * 0.2).round().toString(),
      '0',
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Title and Week indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Task Statistics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'This Week • Dynamic Metrics',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_graph_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${totalComplete + totalProgress} Total',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Chart canvas with dynamic Y-axis markers and spline lines
          SizedBox(
            height: 155,
            child: Row(
              children: [
                // Y-Axis Labels: dynamically calculated ticks
                SizedBox(
                  width: 22,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: yTicks
                        .map(
                          (val) => Text(
                            val,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(width: 10),

                // Spline Lines Painter Area
                Expanded(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _SplineChartPainter(
                      progressData: progress,
                      reviewData: review,
                      completeData: complete,
                      maxY: effectiveMaxY,
                      isDark: isDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // X-Axis Weekday Labels: Mon, Tue, Wed, Thu, Fri, Sat, Sun
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Mon', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('Tue', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('Wed', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('Thu', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('Fri', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('Sat', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('Sun', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Bottom Legend: Progress, Review, Complete with dynamic counts
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(AppColors.chartProgress, 'Progress', totalProgress),
              const SizedBox(width: 14),
              _buildLegendItem(AppColors.chartReview, 'Review', totalReview),
              const SizedBox(width: 14),
              _buildLegendItem(AppColors.chartComplete, 'Complete', totalComplete),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$label ($count)',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _SplineChartPainter extends CustomPainter {
  final List<double> progressData;
  final List<double> reviewData;
  final List<double> completeData;
  final double maxY;
  final bool isDark;

  _SplineChartPainter({
    required this.progressData,
    required this.reviewData,
    required this.completeData,
    required this.maxY,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw faint horizontal gridlines
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    const rowCount = 5;
    for (int i = 0; i <= rowCount; i++) {
      final y = size.height * (i / rowCount);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final effectiveMax = maxY <= 0 ? 5.0 : maxY;

    // Draw spline curves for the 3 datasets
    _drawSpline(canvas, size, progressData, AppColors.chartProgress, effectiveMax);
    _drawSpline(canvas, size, reviewData, AppColors.chartReview, effectiveMax);
    _drawSpline(canvas, size, completeData, AppColors.chartComplete, effectiveMax);
  }

  void _drawSpline(Canvas canvas, Size size, List<double> points, Color color, double maxVal) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final stepX = size.width / (points.length - 1);

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final val = points[i].clamp(0.0, maxVal);
      final y = size.height - (val / maxVal * (size.height - 6)) - 3;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevVal = points[i - 1].clamp(0.0, maxVal);
        final prevY = size.height - (prevVal / maxVal * (size.height - 6)) - 3;

        final controlX1 = prevX + (x - prevX) / 2;
        final controlY1 = prevY;
        final controlX2 = prevX + (x - prevX) / 2;
        final controlY2 = y;

        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw subtle dot at each point with > 0 value
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      if (points[i] > 0) {
        final x = i * stepX;
        final val = points[i].clamp(0.0, maxVal);
        final y = size.height - (val / maxVal * (size.height - 6)) - 3;
        canvas.drawCircle(Offset(x, y), 3.0, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SplineChartPainter oldDelegate) => true;
}
