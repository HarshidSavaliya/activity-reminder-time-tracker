import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/date_time_utils.dart';
import '../../models/activity_model.dart';
import '../../models/enums/activity_priority.dart';
import '../../providers/activity_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/empty_state_view.dart';
import '../activities/widgets/activity_card.dart';

enum CalendarViewMode { day, week, month }

/// CalendarScreen provides Day View, Week View (student timetable), and Month View
/// with navigation, date selection, search, and activity creation.
/// Dynamic scaling enabled for accessibility.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarViewMode _viewMode = CalendarViewMode.day;
  late DateTime _focusedDate;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _focusedDate = DateTime.now();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() => _focusedDate = now);
    context.read<ActivityProvider>().setSelectedDate(now);
  }

  void _navigatePeriod(int direction) {
    setState(() {
      switch (_viewMode) {
        case CalendarViewMode.day:
          _focusedDate = _focusedDate.add(Duration(days: direction));
          context.read<ActivityProvider>().setSelectedDate(_focusedDate);
          break;
        case CalendarViewMode.week:
          _focusedDate = _focusedDate.add(Duration(days: direction * 7));
          context.read<ActivityProvider>().setSelectedDate(_focusedDate);
          break;
        case CalendarViewMode.month:
          _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + direction, 1);
          context.read<ActivityProvider>().setSelectedDate(_focusedDate);
          break;
      }
    });
  }

  List<DateTime> _getCurrentWeekDays(DateTime anchor) {
    final weekday = anchor.weekday;
    final monday = anchor.subtract(Duration(days: weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  String _periodTitle() {
    switch (_viewMode) {
      case CalendarViewMode.day:
        return DateTimeUtils.formatFullDate(_focusedDate);
      case CalendarViewMode.week:
        final days = _getCurrentWeekDays(_focusedDate);
        return '${DateTimeUtils.formatShortDate(days.first)} - ${DateTimeUtils.formatShortDate(days.last)}, ${days.first.year}';
      case CalendarViewMode.month:
        return '${DateTimeUtils.formatDate(_focusedDate)} ${_focusedDate.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final activityCtrl = context.watch<ActivityProvider>();
    final selectedDate = activityCtrl.selectedDate;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Calendar & Routine',
        subtitle: _periodTitle(),
        actions: [
          IconButton(
            tooltip: 'Return to Today',
            icon: const Icon(Icons.today_rounded),
            onPressed: _goToToday,
          ),
          IconButton(
            tooltip: 'Add Activity',
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.activityForm);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Navigation & View Mode Selector Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => _navigatePeriod(-1),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => _navigatePeriod(1),
                  ),
                  const Spacer(),
                  SegmentedButton<CalendarViewMode>(
                    segments: const [
                      ButtonSegment(value: CalendarViewMode.day, label: Text('Day')),
                      ButtonSegment(value: CalendarViewMode.week, label: Text('Week')),
                      ButtonSegment(value: CalendarViewMode.month, label: Text('Month')),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (set) {
                      setState(() => _viewMode = set.first);
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Active View Rendering
            Expanded(
              child: switch (_viewMode) {
                CalendarViewMode.day => _buildDayView(context, activityCtrl, user?.id ?? ''),
                CalendarViewMode.week => _buildWeekView(context, activityCtrl, user?.id ?? ''),
                CalendarViewMode.month => _buildMonthView(context, activityCtrl, selectedDate, user?.id ?? ''),
              },
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - Day View

  Widget _buildDayView(
    BuildContext context,
    ActivityProvider activityCtrl,
    String userId,
  ) {
    final theme = Theme.of(context);
    final selectedDate = activityCtrl.selectedDate;
    final activitiesForDay = activityCtrl.activitiesForSelectedDate;
    final textScaler = MediaQuery.textScalerOf(context);

    // Generate 15 days around focused date
    final weekDays = List.generate(15, (index) {
      return _focusedDate.subtract(const Duration(days: 7)).add(Duration(days: index));
    });

    final stripHeight = textScaler.scale(72.0);

    return Column(
      children: [
        // Horizontal Date Strip with dynamic text scaling
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.space8),
          color: theme.colorScheme.surface,
          child: SizedBox(
            height: stripHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
              itemCount: weekDays.length,
              itemBuilder: (context, index) {
                final day = weekDays[index];
                final isSelected = DateTimeUtils.isSameDay(day, selectedDate);
                final isToday = DateTimeUtils.isToday(day);
                final count = activityCtrl.countForDate(day);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () {
                      setState(() => _focusedDate = day);
                      activityCtrl.setSelectedDate(day);
                    },
                    borderRadius: AppDimensions.borderRadiusMd,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: textScaler.scale(54.0),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        borderRadius: AppDimensions.borderRadiusMd,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateTimeUtils.formatShortWeekday(day),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : isToday
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : isToday
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (isToday && !isSelected)
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            )
                          else if (count > 0)
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            )
                          else
                            const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Search & Priority Filter row with Hide Completed Toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: activityCtrl.setSearchQuery,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search title, room, notes...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              activityCtrl.setSearchQuery('');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.space8),
              IconButton(
                tooltip: activityCtrl.hideCompleted
                    ? 'Completed tasks are hidden (tap to show)'
                    : 'Completed tasks are visible (tap to hide)',
                icon: Icon(
                  activityCtrl.hideCompleted
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: activityCtrl.hideCompleted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                onPressed: () => activityCtrl.toggleHideCompleted(),
              ),
              const SizedBox(width: AppDimensions.space4),
              PopupMenuButton<ActivityPriority?>(
                tooltip: 'Filter Priority',
                icon: Icon(
                  Icons.filter_list_rounded,
                  color: activityCtrl.selectedPriority != null
                      ? theme.colorScheme.primary
                      : null,
                ),
                onSelected: activityCtrl.setPriorityFilter,
                itemBuilder: (context) => [
                  const PopupMenuItem(value: null, child: Text('All Priorities')),
                  const PopupMenuItem(
                      value: ActivityPriority.high, child: Text('High Priority')),
                  const PopupMenuItem(
                      value: ActivityPriority.medium, child: Text('Medium Priority')),
                  const PopupMenuItem(
                      value: ActivityPriority.low, child: Text('Low Priority')),
                ],
              ),
            ],
          ),
        ),

        // Day Activities List organized by Morning, Afternoon, Night time blocks (Image 2)
        Expanded(
          child: activitiesForDay.isEmpty
              ? EmptyStateView(
                  icon: Icons.event_available_rounded,
                  title: 'No activities on this date',
                  message:
                      'Schedule a lecture, lab, or exam for ${DateTimeUtils.formatDate(selectedDate)}.',
                  actionText: 'Add Activity',
                  onAction: () {
                    Navigator.of(context).pushNamed(AppRoutes.activityForm);
                  },
                )
              : _buildTimelineBlocks(activitiesForDay, userId, activityCtrl),
        ),
      ],
    );
  }

  Widget _buildTimelineBlocks(
    List<ActivityModel> activities,
    String userId,
    ActivityProvider activityCtrl,
  ) {
    final morning = activities.where((a) => a.startTime.hour < 12).toList();
    final afternoon = activities
        .where((a) => a.startTime.hour >= 12 && a.startTime.hour < 17)
        .toList();
    final night = activities.where((a) => a.startTime.hour >= 17).toList();

    return ListView(
      padding: AppDimensions.screenPadding,
      children: [
        if (morning.isNotEmpty) ...[
          _buildPeriodHeader('Morning', Icons.wb_sunny_outlined, const Color(0xFFF59E0B)),
          ...morning.map((act) => ActivityCard(
                activity: act,
                userId: userId,
                activityCtrl: activityCtrl,
              )),
          const SizedBox(height: 16),
        ],
        if (afternoon.isNotEmpty) ...[
          _buildPeriodHeader('Afternoon', Icons.wb_twilight_rounded, const Color(0xFF3B82F6)),
          ...afternoon.map((act) => ActivityCard(
                activity: act,
                userId: userId,
                activityCtrl: activityCtrl,
              )),
          const SizedBox(height: 16),
        ],
        if (night.isNotEmpty) ...[
          _buildPeriodHeader('Night', Icons.nightlight_round, const Color(0xFF8B5CF6)),
          ...night.map((act) => ActivityCard(
                activity: act,
                userId: userId,
                activityCtrl: activityCtrl,
              )),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildPeriodHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - Week View (Student Timetable)

  Widget _buildWeekView(
    BuildContext context,
    ActivityProvider activityCtrl,
    String userId,
  ) {
    final theme = Theme.of(context);
    final weekDays = _getCurrentWeekDays(_focusedDate);

    return ListView.builder(
      padding: AppDimensions.screenPadding,
      itemCount: weekDays.length,
      itemBuilder: (context, index) {
        final day = weekDays[index];
        final isToday = DateTimeUtils.isToday(day);
        final occurrences = activityCtrl.getActivitiesForWeek(day).where((a) {
          return DateTimeUtils.isSameDay(a.date, day);
        }).toList();

        return Container(
          margin: const EdgeInsets.only(bottom: AppDimensions.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weekday Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isToday
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surface,
                      borderRadius: AppDimensions.borderRadiusSm,
                      border: Border.all(
                        color: isToday
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                    ),
                    child: Text(
                      '${DateTimeUtils.formatWeekday(day)}, ${day.day} ${DateTimeUtils.formatDate(day).split(' ').last}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isToday ? Colors.white : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: AppDimensions.space8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: AppDimensions.borderRadiusSm,
                      ),
                      child: Text(
                        'TODAY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 20),
                    tooltip: 'Add on this day',
                    onPressed: () {
                      activityCtrl.setSelectedDate(day);
                      Navigator.of(context).pushNamed(AppRoutes.activityForm);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space8),

              if (occurrences.isEmpty)
                Container(
                  width: double.infinity,
                  padding: AppDimensions.padding12,
                  decoration: BoxDecoration(
                    borderRadius: AppDimensions.borderRadiusSm,
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.4),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Text(
                    'No scheduled classes or routines',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                )
              else
                ...occurrences.map((act) => ActivityCard(
                      activity: act,
                      userId: userId,
                      activityCtrl: activityCtrl,
                    )),
            ],
          ),
        );
      },
    );
  }

  // MARK: - Month View

  Widget _buildMonthView(
    BuildContext context,
    ActivityProvider activityCtrl,
    DateTime selectedDate,
    String userId,
  ) {
    final theme = Theme.of(context);
    final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final daysInMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday; // 1 = Mon ... 7 = Sun
    final textScaler = MediaQuery.textScalerOf(context);

    final activitiesForSelectedDay = activityCtrl.activitiesForSelectedDate;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day of week headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .map((day) => Expanded(
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

          // Month Grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 42, // 6 weeks * 7 days
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: textScaler.scale(1.0) > 1.2 ? 0.9 : 1.15,
              ),
              itemBuilder: (context, index) {
                final dayOffset = index - (startingWeekday - 1);
                if (dayOffset < 0 || dayOffset >= daysInMonth) {
                  return const SizedBox.shrink();
                }

                final dayNumber = dayOffset + 1;
                final dayDate = DateTime(_focusedDate.year, _focusedDate.month, dayNumber);
                final isSelected = DateTimeUtils.isSameDay(dayDate, selectedDate);
                final isToday = DateTimeUtils.isToday(dayDate);
                final count = activityCtrl.countForDate(dayDate);

                return InkWell(
                  onTap: () {
                    activityCtrl.setSelectedDate(dayDate);
                  },
                  borderRadius: AppDimensions.borderRadiusSm,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : (isToday
                              ? theme.colorScheme.primary.withValues(alpha: 0.1)
                              : Colors.transparent),
                      borderRadius: AppDimensions.borderRadiusSm,
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (isToday
                                ? theme.colorScheme.primary.withValues(alpha: 0.4)
                                : Colors.transparent),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isToday
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface),
                          ),
                        ),
                        if (count > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : AppColors.primary,
                              borderRadius: AppDimensions.borderRadiusSm,
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? theme.colorScheme.primary : Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 16),

          // Selected Day Header & List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateTimeUtils.formatFullDate(selectedDate),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${activitiesForSelectedDay.length} Activities',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space8),

          if (activitiesForSelectedDay.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: Text(
                  'No activities on this date',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: AppDimensions.screenPadding,
              itemCount: activitiesForSelectedDay.length,
              itemBuilder: (context, index) {
                final item = activitiesForSelectedDay[index];
                return ActivityCard(
                  activity: item,
                  userId: userId,
                  activityCtrl: activityCtrl,
                );
              },
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
