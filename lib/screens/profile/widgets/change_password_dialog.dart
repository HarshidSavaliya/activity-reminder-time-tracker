import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/custom_snackbar.dart';

/// ChangePasswordDialog allows logged-in students to update their password.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const ChangePasswordDialog(),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();

    final success = await auth.changePassword(
      oldPassword: _oldPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      CustomSnackbar.showSuccess(context, 'Password changed successfully');
      Navigator.of(context).pop();
    } else {
      CustomSnackbar.showError(
        context,
        auth.errorMessage ?? 'Failed to change password. Verify your current password.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppDimensions.borderRadiusMd),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Change Password',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: AppDimensions.space8),
                AppTextField(
                  controller: _oldPasswordController,
                  label: 'Current Password',
                  hintText: 'Enter current password',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: (v) => (v == null || v.isEmpty) ? 'Current password is required' : null,
                ),
                const SizedBox(height: AppDimensions.space12),
                AppTextField(
                  controller: _newPasswordController,
                  label: 'New Password',
                  hintText: 'Enter new password',
                  prefixIcon: Icons.lock_reset_rounded,
                  isPassword: true,
                  validator: Validators.validatePassword,
                ),
                const SizedBox(height: AppDimensions.space12),
                AppTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm New Password',
                  hintText: 'Confirm new password',
                  prefixIcon: Icons.lock_reset_rounded,
                  isPassword: true,
                  validator: (v) => Validators.validateConfirmPassword(
                    v,
                    _newPasswordController.text,
                  ),
                ),
                const SizedBox(height: AppDimensions.space20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppDimensions.space8),
                    AppButton(
                      text: 'Update Password',
                      isLoading: _isLoading,
                      onPressed: _handleSave,
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
