import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/app_routes.dart';
import '../../models/activity_model.dart';
import '../../providers/activity_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/empty_state_view.dart';
import '../activities/widgets/activity_card.dart';
import 'widgets/greeting_header.dart';
import 'widgets/hero_activity_card.dart';
import 'widgets/missed_activities_section.dart';
import 'widgets/status_summary_grid.dart';
import 'widgets/task_statistics_chart.dart';

enum HomeFilterTab { all, highPriority, pending, completed }

/// Master-level Home dashboard organized strictly around user priorities and mockup aesthetics:
/// 1. Greeting Header with Avatar and Notification Bell
/// 2. 2x2 Vibrant Status Summary Grid (To do, In progress, In review, Complete)
/// 3. Spline Curves Task Statistics Chart (Progress, Review, Complete)
/// 4. Quick Actions Bar (Add Activity, Import PDF)
/// 5. Current Tasks Section with Hero Purple Card and Activity List
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  HomeFilterTab _currentTab = HomeFilterTab.all;
  bool _dismissedOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool('dismissed_onboarding') ?? false;
    if (mounted) {
      setState(() => _dismissedOnboarding = dismissed);
    }
  }

  Future<void> _dismissOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dismissed_onboarding', true);
    if (mounted) {
      setState(() => _dismissedOnboarding = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      body: SafeArea(
        child: Consumer<ActivityProvider>(
          builder: (context, activityCtrl, child) {
            final todayList = activityCtrl.todayActivities;
            final overdue = activityCtrl.overdueActivities;

            // Filtered list based on active tab
            List<ActivityModel> displayList = todayList;
            if (_currentTab == HomeFilterTab.highPriority) {
              displayList = activityCtrl.highPriorityActivities;
            } else if (_currentTab == HomeFilterTab.pending) {
              displayList = activityCtrl.pendingActivities;
            } else if (_currentTab == HomeFilterTab.completed) {
              displayList = activityCtrl.completedActivities;
            }

            return RefreshIndicator(
              onRefresh: () async {
                if (user != null) {
                  await activityCtrl.refreshActivities(user.id);
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Contextual Greeting & Avatar (Directly from Image 1)
                        GreetingHeader(
                          user: user,
                          onAvatarTap: () {
                            Navigator.of(context).pushNamed(AppRoutes.profile);
                          },
                          onNotificationTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('All reminders are up to date.')),
                            );
                          },
                        ),
                        const SizedBox(height: 18),

                        // 2. 2x2 Colorful Status Summary Grid (To do list, In progress, In review, Complete)
                        StatusSummaryGrid(
                          totalCount: activityCtrl.todayTotalCount,
                          pendingCount: activityCtrl.todayPendingCount,
                          inReviewCount: activityCtrl.highPriorityActivities.length,
                          completedCount: activityCtrl.todayCompletedCount,
                          onCardTapped: (index) {
                            setState(() {
                              switch (index) {
                                case 0:
                                  _currentTab = HomeFilterTab.all;
                                  break;
                                case 1:
                                  _currentTab = HomeFilterTab.pending;
                                  break;
                                case 2:
                                  _currentTab = HomeFilterTab.highPriority;
                                  break;
                                case 3:
                                  _currentTab = HomeFilterTab.completed;
                                  break;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 18),

                        // 3. Spline Curves "Task Statistics" Chart (Dynamic real-time user activity curves)
                        const TaskStatisticsChart(),
                        const SizedBox(height: 18),

                        // 4. Quick Actions Bar (Add Activity, Import PDF)
                        _buildQuickActions(context),
                        const SizedBox(height: 18),

                        // First-time User Onboarding Banner (Skippable)
                        if (!_dismissedOnboarding) ...[
                          _buildOnboardingCard(context),
                          const SizedBox(height: 18),
                        ],

                        // Overdue / Missed Activities (Instant resolution options with undo)
                        if (user != null && overdue.isNotEmpty) ...[
                          MissedActivitiesSection(
                            overdueActivities: overdue,
                            userId: user.id,
                            activityCtrl: activityCtrl,
                          ),
                          const SizedBox(height: 18),
                        ],

                        // 5. Section Header: "Current Tasks" with Hide Completed toggle and "View all"
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Current Tasks',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: activityCtrl.hideCompleted
                                      ? 'Completed tasks are hidden (tap to show)'
                                      : 'Completed tasks are visible (tap to hide)',
                                  icon: Icon(
                                    activityCtrl.hideCompleted
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 18,
                                    color: activityCtrl.hideCompleted
                                        ? AppColors.primary
                                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => activityCtrl.toggleHideCompleted(),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pushNamed(AppRoutes.calendar);
                              },
                              style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              child: const Text(
                                'View all',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Tab Filter Pills (All, High Priority, Pending, Completed)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildTabChip(
                                label: 'All (${todayList.length})',
                                tab: HomeFilterTab.all,
                              ),
                              const SizedBox(width: AppDimensions.space8),
                              _buildTabChip(
                                label: 'High Priority (${activityCtrl.highPriorityActivities.length})',
                                tab: HomeFilterTab.highPriority,
                                badgeColor: AppColors.priorityHigh,
                              ),
                              const SizedBox(width: AppDimensions.space8),
                              _buildTabChip(
                                label: 'Pending (${activityCtrl.pendingActivities.length})',
                                tab: HomeFilterTab.pending,
                              ),
                              const SizedBox(width: AppDimensions.space8),
                              _buildTabChip(
                                label: 'Done (${activityCtrl.completedActivities.length})',
                                tab: HomeFilterTab.completed,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 6. Activities List or Meaningful Empty State
                        if (displayList.isEmpty)
                          _buildMeaningfulEmptyState(context)
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: displayList.length,
                            itemBuilder: (context, index) {
                              final item = displayList[index];

                              // First item is styled as the Hero Purple Card (like "Web app design for admin")
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: HeroActivityCard(
                                    activity: item,
                                    onTap: () {
                                      Navigator.of(context).pushNamed(
                                        AppRoutes.activityDetail,
                                        arguments: item,
                                      );
                                    },
                                    onToggleComplete: () {
                                      if (user != null) {
                                        activityCtrl.toggleCompletion(
                                          user.id,
                                          item.recurrenceParentId ?? item.id,
                                          occurrenceDate: item.occurrenceDate,
                                        );
                                      }
                                    },
                                  ),
                                );
                              }

                              return ActivityCard(
                                activity: item,
                                userId: user?.id ?? '',
                                activityCtrl: activityCtrl,
                              );
                            },
                          ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionTile(
            context,
            icon: Icons.add_rounded,
            label: 'Add Activity',
            color: AppColors.primary,
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.activityForm),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionTile(
            context,
            icon: Icons.upload_file_rounded,
            label: 'Import PDF',
            color: const Color(0xFFE64980),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.pdfImport),
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.waving_hand_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Welcome to Activity Tracker!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Dismiss',
                onPressed: _dismissOnboarding,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Organize your college routines, lectures, and exams. Upload your timetable PDF or create an activity to get started.',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Import PDF Timetable',
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.pdfImport),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _dismissOnboarding,
                child: const Text('Skip Tour'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip({
    required String label,
    required HomeFilterTab tab,
    Color? badgeColor,
  }) {
    final isSelected = _currentTab == tab;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected
              ? Colors.white
              : (badgeColor ?? Theme.of(context).colorScheme.onSurface),
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? AppColors.primary
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      showCheckmark: false,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _currentTab = tab;
          });
        }
      },
    );
  }

  Widget _buildMeaningfulEmptyState(BuildContext context) {
    if (_currentTab == HomeFilterTab.completed) {
      return const EmptyStateView(
        icon: Icons.check_circle_outline_rounded,
        title: 'No completed activities yet',
        message: 'Complete classes or routines by tapping the checkmark on any activity card.',
      );
    } else if (_currentTab == HomeFilterTab.highPriority) {
      return const EmptyStateView(
        icon: Icons.verified_rounded,
        title: 'No high-priority tasks',
        message: 'You have no urgent lectures or deadlines scheduled today.',
      );
    }

    return EmptyStateView(
      icon: Icons.celebration_rounded,
      title: 'No activities today 🎉',
      message: 'Your schedule is clear. Relax, review your study notes, or schedule an activity.',
      actionText: 'Add Activity',
      onAction: () {
        Navigator.of(context).pushNamed(AppRoutes.activityForm);
      },
    );
  }
}

// Backwards compatibility alias
typedef HomeScreen = DashboardScreen;
