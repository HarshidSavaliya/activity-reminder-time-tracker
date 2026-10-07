import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../models/activity_model.dart';
import '../../../widgets/app_button.dart';

/// RescheduleDialog allows selecting a new date and time for an activity or occurrence.
class RescheduleDialog extends StatefulWidget {
  final ActivityModel activity;

  const RescheduleDialog({super.key, required this.activity});

  static Future<Map<String, dynamic>?> show(BuildContext context, ActivityModel activity) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => RescheduleDialog(activity: activity),
    );
  }

  @override
  State<RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<RescheduleDialog> {
  late DateTime _newDate;
  late TimeOfDay _newStartTime;
  TimeOfDay? _newEndTime;

  @override
  void initState() {
    super.initState();
    final initial = widget.activity.occurrenceDate ?? widget.activity.date;
    _newDate = initial;
    _newStartTime = TimeOfDay.fromDateTime(widget.activity.startTime);
    if (widget.activity.endTime != null) {
      _newEndTime = TimeOfDay.fromDateTime(widget.activity.endTime!);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _newDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _newDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _newStartTime,
    );
    if (picked != null) {
      setState(() => _newStartTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _newEndTime ?? _newStartTime,
    );
    if (picked != null) {
      setState(() => _newEndTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: AppDimensions.borderRadiusLg,
      ),
      title: const Text(
        'Reschedule Activity',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.activity.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppDimensions.space16),

            // Date picker tile
            InkWell(
              onTap: _pickDate,
              borderRadius: AppDimensions.borderRadiusSm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: AppDimensions.borderRadiusSm,
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 18),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          Text(
                            DateTimeUtils.formatFullDate(_newDate),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space12),

            // Start & End Time
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickStartTime,
                    borderRadius: AppDimensions.borderRadiusSm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: AppDimensions.borderRadiusSm,
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                Text(
                                  DateTimeUtils.formatTimeOfDay(_newStartTime),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.space8),
                Expanded(
                  child: InkWell(
                    onTap: _pickEndTime,
                    borderRadius: AppDimensions.borderRadiusSm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: AppDimensions.borderRadiusSm,
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timelapse_rounded, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'End',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                Text(
                                  _newEndTime != null
                                      ? DateTimeUtils.formatTimeOfDay(_newEndTime!)
                                      : 'Optional',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: AppButton(
                text: 'Cancel',
                variant: AppButtonVariant.outlined,
                height: 40,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppDimensions.space8),
            Expanded(
              child: AppButton(
                text: 'Confirm',
                height: 40,
                onPressed: () {
                  final startDt = DateTime(
                    _newDate.year,
                    _newDate.month,
                    _newDate.day,
                    _newStartTime.hour,
                    _newStartTime.minute,
                  );
                  DateTime? endDt;
                  if (_newEndTime != null) {
                    endDt = DateTime(
                      _newDate.year,
                      _newDate.month,
                      _newDate.day,
                      _newEndTime!.hour,
                      _newEndTime!.minute,
                    );
                  }

                  Navigator.of(context).pop({
                    'date': _newDate,
                    'startTime': startDt,
                    'endTime': endDt,
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
