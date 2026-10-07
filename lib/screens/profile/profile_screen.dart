import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_snackbar.dart';
import 'widgets/change_password_dialog.dart';
import 'widgets/database_info_dialog.dart';
import 'widgets/edit_profile_dialog.dart';
import 'widgets/notification_settings_dialog.dart';
import 'widgets/theme_settings_dialog.dart';

/// ProfileScreen provides account overview, personal info management, security, and appearance settings.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U';

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Student Profile',
        subtitle: 'Account & Application Settings',
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'App Settings',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.settings),
          ),
        ],
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
                  // 1. Identity Header Card (Profile picture, Name, Email, Username)
                  AppCard(
                    padding: AppDimensions.padding20,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space12),
                        Text(
                          user.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space2),
                        Text(
                          '@${user.username}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space2),
                        Text(
                          user.email,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: AppDimensions.borderRadiusSm,
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            user.college,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space20),

                  // 2. Account Actions
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(context, 'Account Management'),
                        _buildSettingsTile(
                          icon: Icons.edit_note_rounded,
                          title: AppStrings.editProfile,
                          subtitle: 'Update your name, bio, and college metadata',
                          onTap: () => EditProfileDialog.show(context, user),
                        ),
                        const Divider(),
                        _buildSettingsTile(
                          icon: Icons.password_rounded,
                          title: AppStrings.changePassword,
                          subtitle: 'Update your account login security password',
                          onTap: () => ChangePasswordDialog.show(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space16),

                  // 3. Preferences & Features
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(context, 'Preferences & Routine'),
                        _buildSettingsTile(
                          icon: Icons.notifications_none_rounded,
                          title: AppStrings.notificationSettings,
                          subtitle: 'Manage activity alerts and morning briefings',
                          onTap: () => NotificationSettingsDialog.show(context, user),
                        ),
                        const Divider(),
                        _buildSettingsTile(
                          icon: Icons.palette_outlined,
                          title: AppStrings.themeSettings,
                          subtitle: 'Choose Light, Dark, or System visual mode',
                          onTap: () => ThemeSettingsDialog.show(context),
                        ),
                        const Divider(),
                        _buildSettingsTile(
                          icon: Icons.picture_as_pdf_outlined,
                          title: AppStrings.importTimetable,
                          subtitle: 'Extract weekly activities from PDF schedule',
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.pdfImport),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space16),

                  // 4. Offline Storage Engine
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(context, 'Offline Database'),
                        _buildSettingsTile(
                          icon: Icons.storage_rounded,
                          title: 'SQLite Local Database',
                          subtitle: 'Inspect local SQLite 3 offline database & synchronized tables',
                          onTap: () => DatabaseInfoDialog.show(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space24),

                  // 5. Logout Button
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
                  const SizedBox(height: AppDimensions.space32),
                ],
              ),
            ),
          ),
        ),
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
