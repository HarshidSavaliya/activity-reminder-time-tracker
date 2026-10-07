import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../models/extracted_activity_draft.dart';
import '../../../widgets/app_card.dart';

/// DraftPreviewList presents extracted timetable activities cleanly organized
/// chronologically by Day and Time for effortless reading and schedule verification.
class DraftPreviewList extends StatefulWidget {
  final List<ExtractedActivityDraft> drafts;
  final ValueChanged<List<ExtractedActivityDraft>> onDraftsUpdated;
  final ValueChanged<ExtractedActivityDraft> onEditDraft;

  const DraftPreviewList({
    super.key,
    required this.drafts,
    required this.onDraftsUpdated,
    required this.onEditDraft,
  });

  @override
  State<DraftPreviewList> createState() => _DraftPreviewListState();
}

class _DraftPreviewListState extends State<DraftPreviewList> {
  int? _selectedDayFilter; // null = Show All Days

  // Distinct weekdays in order (1 = Mon .. 7 = Sun)
  static const List<int> _allWeekdays = [1, 2, 3, 4, 5, 6, 7];

  static const Map<int, String> _shortDayNames = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  static const Map<int, String> _fullDayNames = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  static const Map<int, Color> _dayColors = {
    1: Color(0xFFE91E63), // Monday Pink
    2: Color(0xFFFF9800), // Tuesday Orange
    3: Color(0xFFFFA726), // Wednesday Amber
    4: Color(0xFF4CAF50), // Thursday Green
    5: Color(0xFF2196F3), // Friday Blue
    6: Color(0xFF9C27B0), // Saturday Purple
    7: Color(0xFF3F51B5), // Sunday Indigo
  };

  List<ExtractedActivityDraft> get _sortedDrafts {
    final list = List<ExtractedActivityDraft>.from(widget.drafts);
    list.sort((a, b) {
      if (a.weekday != b.weekday) return a.weekday.compareTo(b.weekday);
      if (a.startHour != b.startHour) return a.startHour.compareTo(b.startHour);
      return a.startMinute.compareTo(b.startMinute);
    });
    return list;
  }

  Map<int, List<ExtractedActivityDraft>> get _draftsByDay {
    final map = <int, List<ExtractedActivityDraft>>{};
    for (final day in _allWeekdays) {
      final forDay = _sortedDrafts.where((d) => d.weekday == day).toList();
      if (forDay.isNotEmpty) {
        map[day] = forDay;
      }
    }
    return map;
  }

  void _toggleSelection(ExtractedActivityDraft draft) {
    final updated = widget.drafts.map((d) {
      if (d.id == draft.id) {
        return d.copyWith(isSelected: !d.isSelected);
      }
      return d;
    }).toList();
    widget.onDraftsUpdated(updated);
  }

  void _selectAll(bool select) {
    final filter = _selectedDayFilter;
    final updated = widget.drafts.map((d) {
      if (filter == null || d.weekday == filter) {
        return d.copyWith(isSelected: select);
      }
      return d;
    }).toList();
    widget.onDraftsUpdated(updated);
  }

  void _toggleDaySelection(int day, bool select) {
    final updated = widget.drafts.map((d) {
      if (d.weekday == day) {
        return d.copyWith(isSelected: select);
      }
      return d;
    }).toList();
    widget.onDraftsUpdated(updated);
  }

  void _deleteDraft(ExtractedActivityDraft draft) {
    final updated = widget.drafts.where((d) => d.id != draft.id).toList();
    widget.onDraftsUpdated(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = _draftsByDay;
    final totalCount = widget.drafts.length;
    final selectedCount = widget.drafts.where((d) => d.isSelected).length;

    if (totalCount == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.event_busy_rounded,
                size: 44,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 12),
              Text(
                'No activities to display',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Days to show based on active filter
    final displayedDays = _selectedDayFilter == null
        ? grouped.keys.toList()
        : [if (grouped.containsKey(_selectedDayFilter)) _selectedDayFilter!];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Clean Summary & Selection Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: AppDimensions.borderRadiusMd,
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalCount Activities Detected across ${grouped.length} Days',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$selectedCount of $totalCount selected to schedule',
                      style: TextStyle(
                        fontSize: 12,
                        color: selectedCount > 0
                            ? AppColors.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _selectAll(true),
                child: const Text('Select All', style: TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: () => _selectAll(false),
                child: const Text('Deselect All', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.space12),

        // 2. Weekday Quick-Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text('All (${widget.drafts.length})'),
                  selected: _selectedDayFilter == null,
                  onSelected: (_) => setState(() => _selectedDayFilter = null),
                ),
              ),
              ...grouped.entries.map((entry) {
                final dayNum = entry.key;
                final dayDrafts = entry.value;
                final isSelected = _selectedDayFilter == dayNum;
                final shortName = _shortDayNames[dayNum] ?? 'Day';
                final accent = _dayColors[dayNum] ?? AppColors.primary;

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: CircleAvatar(
                      backgroundColor: accent.withValues(alpha: 0.25),
                      radius: 8,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      ),
                    ),
                    label: Text('$shortName (${dayDrafts.length})'),
                    selected: isSelected,
                    onSelected: (_) => setState(() {
                      _selectedDayFilter = isSelected ? null : dayNum;
                    }),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.space16),

        // 3. Chronological Day Sections
        ...displayedDays.map((dayNum) {
          final dayDrafts = grouped[dayNum] ?? [];
          final dayName = _fullDayNames[dayNum] ?? 'Day $dayNum';
          final accentColor = _dayColors[dayNum] ?? AppColors.primary;
          final allDaySelected = dayDrafts.every((d) => d.isSelected);

          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Day Section Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dayName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${dayDrafts.length} ${dayDrafts.length == 1 ? "activity" : "activities"}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => _toggleDaySelection(dayNum, !allDaySelected),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          allDaySelected ? 'Deselect Day' : 'Select Day',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space8),

                // Cards for this Day (Chronological Order)
                ...dayDrafts.map((draft) => _buildActivityCard(context, draft, accentColor)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActivityCard(
    BuildContext context,
    ExtractedActivityDraft draft,
    Color accentColor,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space8),
      child: AppCard(
        borderColor: draft.isSelected
            ? accentColor.withValues(alpha: 0.35)
            : theme.colorScheme.outline.withValues(alpha: 0.1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Checkbox
            Checkbox(
              value: draft.isSelected,
              activeColor: accentColor,
              onChanged: (_) => _toggleSelection(draft),
            ),
            const SizedBox(width: 4),

            // Main Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    draft.title.isEmpty ? '(Untitled Activity)' : draft.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Time & Details Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Time pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              draft.timeFormatted,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Location pill if available
                      if (draft.location.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 12, color: Colors.blue),
                              const SizedBox(width: 3),
                              Text(
                                draft.location,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Faculty / Teacher if available
                      if (draft.faculty != null && draft.faculty!.isNotEmpty)
                        Text(
                          '• ${draft.faculty}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                    ],
                  ),

                  // Duplicate warning if already in routine
                  if (draft.isDuplicate) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '⚠️ Already exists in your routine',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Edit Draft Button
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit Activity',
              onPressed: () => widget.onEditDraft(draft),
            ),

            // Delete Draft Button
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
              tooltip: 'Remove',
              onPressed: () => _deleteDraft(draft),
            ),
          ],
        ),
      ),
    );
  }
}
