import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/activity_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_snackbar.dart';
import '../profile/widgets/change_password_dialog.dart';
import '../profile/widgets/database_info_dialog.dart';
import '../profile/widgets/edit_profile_dialog.dart';
import '../profile/widgets/notification_settings_dialog.dart';
import '../profile/widgets/theme_settings_dialog.dart';

/// SettingsScreen provides comprehensive controls for:
/// - Activity display (Hide/Show completed activities)
/// - Timetable Extraction Engine (Adobe Acrobat Services & Local Parsing)
/// - Push notifications & alarm reminders
/// - Visual Theme & appearance modes
/// - Local SQLite database & synchronization
/// - Account security & credentials
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final activityCtrl = context.watch<ActivityProvider>();

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Settings',
        subtitle: 'Preferences, AI Engines & Account',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppDimensions.screenPadding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Task & Schedule View Preferences
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(context, 'Activity & View Preferences'),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Hide Completed Activities',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'When enabled, finished tasks are automatically removed from your active schedule and current tasks list.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          value: activityCtrl.hideCompleted,
                          activeTrackColor: AppColors.primary,
                          onChanged: (val) {
                            activityCtrl.setHideCompleted(val);
                            CustomSnackbar.showInfo(
                              context,
                              val
                                  ? 'Completed tasks are now hidden from active view.'
                                  : 'Completed tasks are now visible.',
                            );
                          },
                        ),
                        const Divider(),
                        _buildSettingsTile(
                          icon: Icons.calendar_view_week_rounded,
                          title: 'Default Routine View',
                          subtitle: 'Organize schedule by Day, Week timetable, or Month',
                          onTap: () {
                            Navigator.of(context).pushNamed(AppRoutes.calendar);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space16),

                  // 2. Timetable PDF Extraction
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(context, 'Timetable & PDF Parsing'),
                        _buildSettingsTile(
                          icon: Icons.picture_as_pdf_rounded,
                          title: 'Adobe Acrobat Services & Embed API',
                          subtitle: 'Adobe client credentials & high-fidelity PDF timetable viewer',
                          onTap: () {
                            _showAdobeInfoDialog(context);
                          },
                        ),
                        const Divider(),
                        _buildSettingsTile(
                          icon: Icons.upload_file_rounded,
                          title: 'Import Timetable PDF',
                          subtitle: 'Upload college timetable PDF and convert to recurring tasks',
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.pdfImport),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space16),

                  // 3. Notifications & Alarms
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(context, 'Notifications & Alerts'),
                        _buildSettingsTile(
                          icon: Icons.notifications_active_outlined,
                          title: AppStrings.notificationSettings,
                          subtitle: 'Manage activity reminders, sound, vibration, and morning digest',
                          onTap: () {
                            if (user != null) {
                              NotificationSettingsDialog.show(context, user);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space16),

                  // 4. Appearance & Visual Theme
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(context, 'Appearance & Theme'),
                        _buildSettingsTile(
                          icon: Icons.palette_outlined,
                          title: AppStrings.themeSettings,
                          subtitle: 'Toggle between Dark, Light, or System default theme',
                          onTap: () => ThemeSettingsDialog.show(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space16),

                  // 5. Database & Offline Storage
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(context, 'Offline Storage & Engine'),
                        _buildSettingsTile(
                          icon: Icons.storage_rounded,
                          title: 'SQLite 3 Database Inspector',
                          subtitle: 'Inspect local SQLite offline records, tables, and conflict logs',
                          onTap: () => DatabaseInfoDialog.show(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space16),

                  // 6. Account & Security
                  if (user != null) ...[
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(context, 'Account & Security'),
                          _buildSettingsTile(
                            icon: Icons.person_outline_rounded,
                            title: AppStrings.editProfile,
                            subtitle: 'Update your student details, college, and bio',
                            onTap: () => EditProfileDialog.show(context, user),
                          ),
                          const Divider(),
                          _buildSettingsTile(
                            icon: Icons.lock_outline_rounded,
                            title: AppStrings.changePassword,
                            subtitle: 'Update login authentication credentials',
                            onTap: () => ChangePasswordDialog.show(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space20),

                    // Logout Button
                    AppButton(
                      text: AppStrings.logoutTitle,
                      icon: Icons.logout_rounded,
                      variant: AppButtonVariant.danger,
                      onPressed: () async {
                        final confirmed = await ConfirmationDialog.show(
                          context,
                          title: AppStrings.logoutTitle,
                          message: AppStrings.logoutConfirm,
                          confirmText: 'Sign Out',
                          isDestructive: true,
                        );

                        if (confirmed == true && context.mounted) {
                          await auth.logout();
                          if (context.mounted) {
                            CustomSnackbar.showInfo(context, 'You have been signed out.');
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              AppRoutes.login,
                              (route) => false,
                            );
                          }
                        }
                      },
                    ),
                  ],

                  const SizedBox(height: AppDimensions.space24),
                  Center(
                    child: Text(
                      'Activity Reminder Tracker • v1.2.0 (Offline-First)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAdobeInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFE11D48)),
            SizedBox(width: 8),
            Text('Adobe Acrobat Services'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adobe PDF Services Integration is active with both client-side and cloud extraction capabilities:',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 10),
            Text(
              '• Adobe Acrobat PDF Extract API (Table & Timetable Structure)\n'
              '• Adobe PDF Embed API (In-App High-Fidelity Viewer)\n'
              '• FlateDecode stream decompressor for pure local timetable reading\n'
              '• Strict validation ensures no fake/dummy data is generated when unreadable',
              style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppDimensions.borderRadiusSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMutedLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMutedLight),
          ],
        ),
      ),
    );
  }
}
