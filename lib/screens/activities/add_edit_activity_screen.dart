import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/date_time_utils.dart';
import '../../core/utils/validators.dart';
import '../../models/activity_model.dart';
import '../../models/enums/activity_category.dart';
import '../../models/enums/activity_priority.dart';
import '../../models/enums/activity_source.dart';
import '../../models/enums/activity_status.dart';
import '../../models/recurrence_rule.dart';
import '../../models/reminder_setting.dart';
import '../../providers/activity_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/custom_snackbar.dart';

/// AddEditActivityScreen provides a streamlined, accessible form for creating
/// and modifying activities with recurrence rules, reminders, duration shortcuts,
/// and conflict detection.
class AddEditActivityScreen extends StatefulWidget {
  final ActivityModel? existingActivity;

  const AddEditActivityScreen({super.key, this.existingActivity});

  @override
  State<AddEditActivityScreen> createState() => _AddEditActivityScreenState();
}

class _AddEditActivityScreenState extends State<AddEditActivityScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;

  late ActivityCategory _category;
  late ActivityPriority _priority;
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  TimeOfDay? _endTime;

  // Reminders
  late int _reminderMinutes;
  bool _customReminder = false;

  // Recurrence
  late RecurrenceType _recurrenceType;
  late int _repeatInterval;
  late List<int> _selectedWeekdays;
  DateTime? _recurrenceEndDate;

  bool _isLoading = false;

  bool get isEditing => widget.existingActivity != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingActivity;

    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _locationController = TextEditingController(text: existing?.location ?? '');

    _category = existing?.category ?? ActivityCategory.lecture;
    _priority = existing?.priority ?? ActivityPriority.high;

    final initialDateTime = existing?.startTime ?? DateTime.now();
    _selectedDate = existing?.date ??
        DateTime(initialDateTime.year, initialDateTime.month, initialDateTime.day);
    _startTime = TimeOfDay(hour: initialDateTime.hour, minute: initialDateTime.minute);

    if (existing?.endTime != null) {
      _endTime = TimeOfDay(hour: existing!.endTime!.hour, minute: existing.endTime!.minute);
    } else {
      _endTime = TimeOfDay(hour: (_startTime.hour + 1) % 24, minute: _startTime.minute);
    }

    _reminderMinutes = existing?.reminder.minutesBefore ?? 15;
    _customReminder =
        ![0, 5, 10, 15, 30, 60].contains(_reminderMinutes) && _reminderMinutes > 0;

    _recurrenceType = existing?.recurrence.type ?? RecurrenceType.never;
    _repeatInterval = existing?.recurrence.interval ?? 1;
    _selectedWeekdays = List<int>.from(existing?.recurrence.selectedWeekdays ?? [1, 3, 5]);
    _recurrenceEndDate = existing?.recurrence.endDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _addDuration(Duration duration) {
    final startDt = DateTime(2026, 1, 1, _startTime.hour, _startTime.minute);
    final endDt = startDt.add(duration);
    setState(() {
      _endTime = TimeOfDay(hour: endDt.hour, minute: endDt.minute);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        if (_endTime != null && _isTimeBefore(_endTime!, picked)) {
          _endTime = TimeOfDay(hour: (picked.hour + 1) % 24, minute: picked.minute);
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay(hour: (_startTime.hour + 1) % 24, minute: _startTime.minute),
    );
    if (picked != null) {
      if (_isTimeBefore(picked, _startTime)) {
        if (!mounted) return;
        CustomSnackbar.showError(context, 'End time cannot be earlier than start time');
        return;
      }
      setState(() => _endTime = picked);
    }
  }

  bool _isTimeBefore(TimeOfDay a, TimeOfDay b) {
    if (a.hour < b.hour) return true;
    if (a.hour == b.hour && a.minute < b.minute) return true;
    return false;
  }

  Future<void> _pickRecurrenceEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate ?? _selectedDate.add(const Duration(days: 90)),
      firstDate: _selectedDate,
      lastDate: _selectedDate.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _recurrenceEndDate = picked);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) {
      CustomSnackbar.showError(context, 'Please sign in to save activities');
      return;
    }

    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    DateTime? endDateTime;
    if (_endTime != null) {
      endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime!.hour,
        _endTime!.minute,
      );

      if (endDateTime.isBefore(startDateTime)) {
        CustomSnackbar.showError(context, 'End time cannot be before start time');
        return;
      }
    }

    final activityCtrl = context.read<ActivityProvider>();

    final conflictingActivity = activityCtrl.getConflictingActivity(
      date: _selectedDate,
      startTime: startDateTime,
      endTime: endDateTime,
      excludeActivityId: widget.existingActivity?.id,
    );

    if (conflictingActivity != null) {
      final continueAnyway = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('Schedule Conflict'),
            ],
          ),
          content: Text(
            'You already have an activity scheduled at this time:\n\n'
            '• "${conflictingActivity.title}" '
            '(${DateTimeUtils.formatTimeRange(conflictingActivity.startTime, conflictingActivity.endTime)})\n\n'
            'Do you want to continue and schedule anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Adjust Time'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue Anyway'),
            ),
          ],
        ),
      );

      if (continueAnyway != true) {
        return;
      }
    }

    setState(() => _isLoading = true);

    final recurrenceRule = RecurrenceRule(
      type: _recurrenceType,
      interval: _repeatInterval,
      selectedWeekdays: _recurrenceType == RecurrenceType.custom ? _selectedWeekdays : [],
      startDate: _selectedDate,
      endDate: _recurrenceEndDate,
    );

    final reminderSetting = ReminderSetting(
      minutesBefore: _reminderMinutes,
      isEnabled: _reminderMinutes >= 0,
    );

    bool success = false;
    final existing = widget.existingActivity;

    if (existing != null) {
      final updated = existing.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        category: _category,
        priority: _priority,
        date: _selectedDate,
        startTime: startDateTime,
        endTime: endDateTime,
        reminder: reminderSetting,
        recurrence: recurrenceRule,
        updatedAt: DateTime.now(),
      );
      success = await activityCtrl.updateActivity(updated);
    } else {
      success = await activityCtrl.createActivity(
        userId: user.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        date: _selectedDate,
        startTime: startDateTime,
        endTime: endDateTime,
        priority: _priority,
        status: ActivityStatus.pending,
        reminder: reminderSetting,
        recurrence: recurrenceRule,
        location: _locationController.text.trim(),
        source: ActivitySource.manual,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      CustomSnackbar.showSuccess(
        context,
        isEditing ? 'Activity updated successfully!' : 'Activity scheduled successfully!',
      );
      Navigator.of(context).pop();
    } else {
      CustomSnackbar.showError(
        context,
        activityCtrl.errorMessage ?? 'Failed to save activity.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Activity' : 'New Activity'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppDimensions.screenPadding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Basic Info
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            controller: _titleController,
                            label: AppStrings.activityTitleLabel,
                            hintText: AppStrings.activityTitleHint,
                            prefixIcon: Icons.title_rounded,
                            textCapitalization: TextCapitalization.sentences,
                            validator: Validators.validateActivityTitle,
                          ),
                          const SizedBox(height: AppDimensions.space16),
                          AppTextField(
                            controller: _locationController,
                            label: AppStrings.locationLabel,
                            hintText: AppStrings.locationHint,
                            prefixIcon: Icons.place_outlined,
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: AppDimensions.space16),
                          AppTextField(
                            controller: _descriptionController,
                            label: AppStrings.activityDescriptionLabel,
                            hintText: AppStrings.activityDescriptionHint,
                            prefixIcon: Icons.notes_rounded,
                            maxLines: 3,
                            minLines: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space16),

                    // 2. Category Chips with distinct icons
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.categoryLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.space12),
                          Wrap(
                            spacing: AppDimensions.space8,
                            runSpacing: AppDimensions.space8,
                            children: ActivityCategory.values.map((cat) {
                              final isSelected = _category == cat;
                              return ChoiceChip(
                                avatar: Icon(
                                  cat.icon,
                                  size: 16,
                                  color: isSelected ? Colors.white : cat.color,
                                ),
                                label: Text(cat.displayName),
                                selected: isSelected,
                                selectedColor: cat.color,
                                onSelected: (_) => setState(() => _category = cat),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space16),

                    // 3. Priority Selection with distinct icons for color-blind accessibility
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.priorityLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.space12),
                          Row(
                            children: ActivityPriority.values.map((p) {
                              final isSelected = _priority == p;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: InkWell(
                                    onTap: () => setState(() => _priority = p),
                                    borderRadius: AppDimensions.borderRadiusSm,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? p.color.withValues(alpha: 0.15)
                                            : Colors.transparent,
                                        borderRadius: AppDimensions.borderRadiusSm,
                                        border: Border.all(
                                          color: isSelected ? p.color : theme.colorScheme.outline,
                                          width: isSelected ? 1.8 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(p.icon, size: 14, color: p.color),
                                          const SizedBox(width: AppDimensions.space4),
                                          Text(
                                            p.displayName,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? p.color
                                                  : theme.colorScheme.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space16),

                    // 4. Date & Times (Start, End) with Quick Entry Duration Chips
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Date and Time',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Date Picker Pill Container (Directly from Mockup)
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.colorScheme.outline.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      DateTimeUtils.formatFullDate(_selectedDate),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // From & To side-by-side Time Selector Pills
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _pickStartTime,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: theme.colorScheme.outline.withValues(alpha: 0.12),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 16, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'From',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                                ),
                                              ),
                                              Text(
                                                DateTimeUtils.formatTimeOfDay(_startTime),
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: _pickEndTime,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: theme.colorScheme.outline.withValues(alpha: 0.12),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.timelapse_rounded, size: 16, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'To',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                                ),
                                              ),
                                              Text(
                                                _endTime != null
                                                    ? DateTimeUtils.formatTimeOfDay(_endTime!)
                                                    : 'Not set',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Quick Entry Duration Chips (+15 min, +30 min, +1 hr)
                          Text(
                            'Quick Duration:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.add_rounded, size: 14),
                                label: const Text('+15 min'),
                                onPressed: () => _addDuration(const Duration(minutes: 15)),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.add_rounded, size: 14),
                                label: const Text('+30 min'),
                                onPressed: () => _addDuration(const Duration(minutes: 30)),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.add_rounded, size: 14),
                                label: const Text('+1 hr'),
                                onPressed: () => _addDuration(const Duration(hours: 1)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space16),

                    // 5. Reminders & Alerts
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.notifications_active_outlined, size: 20),
                                  SizedBox(width: AppDimensions.space12),
                                  Text(
                                    AppStrings.reminderLabel,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              DropdownButton<int>(
                                value: _customReminder ? -1 : _reminderMinutes,
                                underline: const SizedBox.shrink(),
                                items: const [
                                  DropdownMenuItem(value: -1, child: Text('Custom alert...')),
                                  DropdownMenuItem(value: 0, child: Text('At activity time')),
                                  DropdownMenuItem(value: 5, child: Text('5 min before')),
                                  DropdownMenuItem(value: 10, child: Text('10 min before')),
                                  DropdownMenuItem(value: 15, child: Text('15 min before')),
                                  DropdownMenuItem(value: 30, child: Text('30 min before')),
                                  DropdownMenuItem(value: 60, child: Text('1 hour before')),
                                ],
                                onChanged: (val) {
                                  if (val == -1) {
                                    _promptCustomMinutes();
                                  } else if (val != null) {
                                    setState(() {
                                      _reminderMinutes = val;
                                      _customReminder = false;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          if (_customReminder) ...[
                            const SizedBox(height: AppDimensions.space8),
                            Text(
                              'Custom Alert: $_reminderMinutes minutes before start',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space16),

                    // 6. Recurrence / Routine Scheduling
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.repeat_rounded, size: 20),
                              const SizedBox(width: AppDimensions.space12),
                              const Text(
                                AppStrings.recurrenceLabel,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              DropdownButton<RecurrenceType>(
                                value: _recurrenceType,
                                underline: const SizedBox.shrink(),
                                items: RecurrenceType.values.map((t) {
                                  return DropdownMenuItem(value: t, child: Text(t.label));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _recurrenceType = val);
                                },
                              ),
                            ],
                          ),

                          if (_recurrenceType == RecurrenceType.custom) ...[
                            const Divider(height: 20),
                            const Text(
                              'Repeat on Weekdays:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: AppDimensions.space8),
                            Wrap(
                              spacing: 6,
                              children: [
                                (1, 'Mon'),
                                (2, 'Tue'),
                                (3, 'Wed'),
                                (4, 'Thu'),
                                (5, 'Fri'),
                                (6, 'Sat'),
                                (7, 'Sun'),
                              ].map((tuple) {
                                final dayNum = tuple.$1;
                                final dayName = tuple.$2;
                                final isSelected = _selectedWeekdays.contains(dayNum);

                                return FilterChip(
                                  label: Text(dayName),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedWeekdays.add(dayNum);
                                      } else {
                                        _selectedWeekdays.remove(dayNum);
                                      }
                                      _selectedWeekdays.sort();
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],

                          if (_recurrenceType != RecurrenceType.never) ...[
                            const Divider(height: 20),
                            InkWell(
                              onTap: _pickRecurrenceEndDate,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Recurrence End Date',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        _recurrenceEndDate != null
                                            ? DateTimeUtils.formatFullDate(_recurrenceEndDate!)
                                            : 'No end date (Continuous / Ongoing)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_recurrenceEndDate != null)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () => setState(() => _recurrenceEndDate = null),
                                    )
                                  else
                                    const Icon(Icons.chevron_right_rounded, size: 20),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space24),

                    // Save Button
                    AppButton(
                      text: isEditing ? AppStrings.updateActivity : AppStrings.saveActivity,
                      isLoading: _isLoading,
                      onPressed: _handleSave,
                    ),
                    const SizedBox(height: AppDimensions.space32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _promptCustomMinutes() {
    final controller = TextEditingController(text: '45');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Reminder'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Minutes before start',
            suffixText: 'mins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final mins = int.tryParse(controller.text);
              if (mins != null && mins > 0) {
                setState(() {
                  _reminderMinutes = mins;
                  _customReminder = true;
                });
                Navigator.of(context).pop();
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}
