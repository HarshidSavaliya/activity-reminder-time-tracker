import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/validators.dart';
import '../../providers/activity_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/custom_snackbar.dart';

/// RegisterScreen provides registration with validation, isolation setup, and onboarding.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _collegeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _collegeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();

    final success = await auth.register(
      name: _nameController.text,
      username: _usernameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      college: _collegeController.text.isNotEmpty
          ? _collegeController.text
          : 'College of Engineering & Technology',
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      final user = auth.currentUser!;
      await context.read<ActivityProvider>().loadActivities(user.id);
      if (!mounted) return;
      CustomSnackbar.showSuccess(context, 'Account created! Welcome, ${user.name}.');
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
    } else {
      CustomSnackbar.showError(
        context,
        auth.errorMessage ?? 'Registration failed. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
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
                      AppStrings.registerTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space8),
                    Text(
                      AppStrings.registerSubtitle,
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
                            controller: _nameController,
                            label: AppStrings.nameLabel,
                            hintText: AppStrings.nameHint,
                            prefixIcon: Icons.badge_outlined,
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return AppStrings.nameRequired;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppDimensions.space16),
                          AppTextField(
                            controller: _usernameController,
                            label: 'Username',
                            hintText: 'e.g. alex_student',
                            prefixIcon: Icons.alternate_email_rounded,
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Username is required';
                              }
                              if (val.length < 3) {
                                return 'Username must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppDimensions.space16),
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
                            controller: _collegeController,
                            label: 'College / University',
                            hintText: 'e.g. Stanford University',
                            prefixIcon: Icons.school_outlined,
                          ),
                          const SizedBox(height: AppDimensions.space16),
                          AppTextField(
                            controller: _passwordController,
                            label: AppStrings.passwordLabel,
                            hintText: AppStrings.passwordHint,
                            prefixIcon: Icons.lock_outline_rounded,
                            isPassword: true,
                            validator: Validators.validatePassword,
                          ),
                          const SizedBox(height: AppDimensions.space16),
                          AppTextField(
                            controller: _confirmPasswordController,
                            label: AppStrings.confirmPasswordLabel,
                            hintText: AppStrings.confirmPasswordHint,
                            prefixIcon: Icons.lock_outline_rounded,
                            isPassword: true,
                            validator: (val) {
                              return Validators.validateConfirmPassword(
                                val,
                                _passwordController.text,
                              );
                            },
                          ),
                          const SizedBox(height: AppDimensions.space24),
                          AppButton(
                            text: AppStrings.registerButton,
                            isLoading: _isLoading,
                            onPressed: _handleRegister,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Sign In',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
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
