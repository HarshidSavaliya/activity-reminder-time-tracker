import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../models/enums/activity_category.dart';
import '../../../models/enums/activity_priority.dart';
import '../../../models/extracted_activity_draft.dart';
import '../../../models/recurrence_rule.dart';
import '../../../widgets/app_button.dart';

/// Modal dialog for editing an extracted activity draft prior to final import.
class EditDraftDialog extends StatefulWidget {
  final ExtractedActivityDraft draft;
  final ValueChanged<ExtractedActivityDraft> onSave;

  const EditDraftDialog({
    super.key,
    required this.draft,
    required this.onSave,
  });

  @override
  State<EditDraftDialog> createState() => _EditDraftDialogState();
}

class _EditDraftDialogState extends State<EditDraftDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _facultyController;

  late int _weekday;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late ActivityCategory _category;
  late ActivityPriority _priority;
  late RecurrenceType _recurrenceType;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.draft.title);
    _locationController = TextEditingController(text: widget.draft.location);
    _facultyController = TextEditingController(text: widget.draft.faculty ?? '');

    _weekday = widget.draft.weekday;
    _startTime = TimeOfDay(
      hour: widget.draft.startHour,
      minute: widget.draft.startMinute,
    );
    _endTime = TimeOfDay(
      hour: widget.draft.endHour,
      minute: widget.draft.endMinute,
    );
    _category = widget.draft.category;
    _priority = widget.draft.priority;
    _recurrenceType = widget.draft.recurrence.type;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _facultyController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          final sMin = _startTime.hour * 60 + _startTime.minute;
          final eMin = _endTime.hour * 60 + _endTime.minute;
          if (eMin <= sMin) {
            _endTime = TimeOfDay(
              hour: (_startTime.hour + 1) % 24,
              minute: _startTime.minute,
            );
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final sMin = _startTime.hour * 60 + _startTime.minute;
    final eMin = _endTime.hour * 60 + _endTime.minute;
    if (eMin <= sMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    final updated = widget.draft.copyWith(
      title: _titleController.text.trim(),
      location: _locationController.text.trim(),
      faculty: _facultyController.text.trim().isEmpty ? null : _facultyController.text.trim(),
      category: _category,
      priority: _priority,
      weekday: _weekday,
      startHour: _startTime.hour,
      startMinute: _startTime.minute,
      endHour: _endTime.hour,
      endMinute: _endTime.minute,
      recurrence: RecurrenceRule(
        type: _recurrenceType,
        selectedWeekdays: _recurrenceType == RecurrenceType.weekly ? [_weekday] : [],
      ),
      confidence: ExtractionConfidence.high,
      confidenceNotes: [],
      isDuplicate: false,
      duplicateReason: null,
      isSelected: true,
    );

    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppDimensions.borderRadiusMd),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: AppDimensions.borderRadiusSm,
                      ),
                      child: Icon(
                        Icons.edit_note_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    const Expanded(
                      child: Text(
                        'Edit Extracted Activity',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Activity / Subject Title',
                            prefixIcon: Icon(Icons.title_rounded, size: 20),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Title cannot be empty' : null,
                        ),
                        const SizedBox(height: AppDimensions.space12),

                        // Weekday & Category Row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: _weekday,
                                decoration: const InputDecoration(
                                  labelText: 'Day of Week',
                                  prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 1, child: Text('Monday')),
                                  DropdownMenuItem(value: 2, child: Text('Tuesday')),
                                  DropdownMenuItem(value: 3, child: Text('Wednesday')),
                                  DropdownMenuItem(value: 4, child: Text('Thursday')),
                                  DropdownMenuItem(value: 5, child: Text('Friday')),
                                  DropdownMenuItem(value: 6, child: Text('Saturday')),
                                  DropdownMenuItem(value: 7, child: Text('Sunday')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _weekday = val);
                                },
                              ),
                            ),
                            const SizedBox(width: AppDimensions.space12),
                            Expanded(
                              child: DropdownButtonFormField<ActivityCategory>(
                                initialValue: _category,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  prefixIcon: Icon(Icons.category_rounded, size: 18),
                                ),
                                items: ActivityCategory.values.map((cat) {
                                  return DropdownMenuItem(
                                    value: cat,
                                    child: Text(cat.displayName),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _category = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.space12),

                        // Time Range Pickers
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _pickTime(isStart: true),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Start Time',
                                    prefixIcon: Icon(Icons.access_time_rounded, size: 18),
                                  ),
                                  child: Text(_startTime.format(context)),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.space12),
                            Expanded(
                              child: InkWell(
                                onTap: () => _pickTime(isStart: false),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'End Time',
                                    prefixIcon: Icon(Icons.access_time_filled_rounded, size: 18),
                                  ),
                                  child: Text(_endTime.format(context)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.space12),

                        // Location
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Location / Room / Lab',
                            prefixIcon: Icon(Icons.place_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space12),

                        // Faculty / Notes
                        TextFormField(
                          controller: _facultyController,
                          decoration: const InputDecoration(
                            labelText: 'Instructor / Faculty (Optional)',
                            prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space12),

                        // Priority & Recurrence
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<ActivityPriority>(
                                initialValue: _priority,
                                decoration: const InputDecoration(
                                  labelText: 'Priority',
                                  prefixIcon: Icon(Icons.flag_rounded, size: 18),
                                ),
                                items: ActivityPriority.values.map((p) {
                                  return DropdownMenuItem(
                                    value: p,
                                    child: Text(p.displayName),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _priority = val);
                                },
                              ),
                            ),
                            const SizedBox(width: AppDimensions.space12),
                            Expanded(
                              child: DropdownButtonFormField<RecurrenceType>(
                                initialValue: _recurrenceType,
                                decoration: const InputDecoration(
                                  labelText: 'Recurrence',
                                  prefixIcon: Icon(Icons.repeat_rounded, size: 18),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: RecurrenceType.weekly,
                                    child: Text('Every Week'),
                                  ),
                                  DropdownMenuItem(
                                    value: RecurrenceType.none,
                                    child: Text('One-time'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _recurrenceType = val);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.space16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppDimensions.space8),
                    AppButton(
                      text: 'Apply Changes',
                      onPressed: _save,
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
}
