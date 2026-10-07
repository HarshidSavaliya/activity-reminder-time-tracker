import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/custom_snackbar.dart';

/// ForgotPasswordScreen provides password reset flow.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();

    final success = await auth.resetPassword(
      email: _emailController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      CustomSnackbar.showSuccess(
        context,
        'Password updated successfully! Please sign in with your new password.',
      );
      Navigator.of(context).pop();
    } else {
      CustomSnackbar.showError(
        context,
        auth.errorMessage ?? 'Password reset failed. Verify your email.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppDimensions.screenPadding,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppStrings.forgotPasswordTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space8),
                    Text(
                      AppStrings.forgotPasswordSubtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space24),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            controller: _emailController,
                            label: AppStrings.emailLabel,
                            hintText: AppStrings.emailHint,
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.validateEmail,
                          ),
                          const SizedBox(height: AppDimensions.space16),
                          AppTextField(
                            controller: _newPasswordController,
                            label: 'New Password',
                            hintText: 'Enter new password',
                            prefixIcon: Icons.lock_outline_rounded,
                            isPassword: true,
                            validator: Validators.validatePassword,
                          ),
                          const SizedBox(height: AppDimensions.space16),
                          AppTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirm New Password',
                            hintText: 'Re-enter new password',
                            prefixIcon: Icons.lock_outline_rounded,
                            isPassword: true,
                            validator: (val) => Validators.validateConfirmPassword(
                              val,
                              _newPasswordController.text,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.space24),
                          AppButton(
                            text: AppStrings.forgotPasswordButton,
                            isLoading: _isLoading,
                            onPressed: _handleReset,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
