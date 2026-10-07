import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/custom_snackbar.dart';

/// NotificationSettingsDialog configures alert preferences.
class NotificationSettingsDialog extends StatefulWidget {
  final UserModel user;

  const NotificationSettingsDialog({super.key, required this.user});

  static Future<void> show(BuildContext context, UserModel user) {
    return showDialog(
      context: context,
      builder: (context) => NotificationSettingsDialog(user: user),
    );
  }

  @override
  State<NotificationSettingsDialog> createState() => _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState extends State<NotificationSettingsDialog> {
  late bool _reminders;
  late bool _dailyDigest;
  late bool _sound;
  late bool _vibration;

  @override
  void initState() {
    super.initState();
    _reminders = widget.user.remindersEnabled;
    _dailyDigest = widget.user.dailyDigestEnabled;
    _sound = widget.user.soundEnabled;
    _vibration = widget.user.vibrationEnabled;
  }

  Future<void> _handleSave() async {
    final auth = context.read<AuthProvider>();
    final updated = widget.user.copyWith(
      remindersEnabled: _reminders,
      dailyDigestEnabled: _dailyDigest,
      soundEnabled: _sound,
      vibrationEnabled: _vibration,
    );

    await auth.updateProfile(updated);
    if (!mounted) return;
    CustomSnackbar.showSuccess(context, 'Notification settings saved');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: AppDimensions.borderRadiusLg,
      ),
      title: const Text(
        'Notification Settings',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activity Reminders', style: TextStyle(fontSize: 14)),
              subtitle: Text(
                'Receive alerts before scheduled classes and tasks',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              value: _reminders,
              onChanged: (val) => setState(() => _reminders = val),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Daily Morning Digest', style: TextStyle(fontSize: 14)),
              subtitle: Text(
                'Summary of upcoming lectures at 7:30 AM',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              value: _dailyDigest,
              onChanged: (val) => setState(() => _dailyDigest = val),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notification Sound', style: TextStyle(fontSize: 14)),
              value: _sound,
              onChanged: (val) => setState(() => _sound = val),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vibration Feedback', style: TextStyle(fontSize: 14)),
              value: _vibration,
              onChanged: (val) => setState(() => _vibration = val),
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
                height: 42,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: AppButton(
                text: 'Save',
                height: 42,
                onPressed: _handleSave,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
