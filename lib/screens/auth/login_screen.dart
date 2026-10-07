import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
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

/// LoginScreen provides clean sign-in with full validation and session persistence.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();

    final success = await auth.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      final user = auth.currentUser!;
      await context.read<ActivityProvider>().loadActivities(user.id);
      if (!mounted) return;
      CustomSnackbar.showSuccess(context, 'Welcome back, ${user.name}!');
      Navigator.of(context).pushReplacementNamed(AppRoutes.main);
    } else {
      CustomSnackbar.showError(
        context,
        auth.errorMessage ?? 'Invalid email or password',
      );
    }
  }

  void _fillDemoCredentials() {
    _emailController.text = 'alex@college.edu';
    _passwordController.text = 'Password123';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
                    const SizedBox(height: AppDimensions.space20),
                    // Header Brand
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppDimensions.borderRadiusMd,
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space16),
                    Text(
                      AppStrings.loginTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space8),
                    Text(
                      AppStrings.loginSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space32),

                    // Inputs Card
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
                            controller: _passwordController,
                            label: AppStrings.passwordLabel,
                            hintText: AppStrings.passwordHint,
                            prefixIcon: Icons.lock_outline_rounded,
                            isPassword: true,
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return AppStrings.passwordRequired;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppDimensions.space8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pushNamed(AppRoutes.forgotPassword);
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              ),
                              child: const Text(
                                AppStrings.forgotPasswordPrompt,
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.space12),
                          AppButton(
                            text: AppStrings.loginButton,
                            isLoading: _isLoading,
                            onPressed: _handleLogin,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space16),

                    // Demo login helper chip
                    Center(
                      child: ActionChip(
                        avatar: const Icon(Icons.bolt_rounded, size: 16),
                        label: const Text(
                          'Fill Demo Account (alex@college.edu)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        onPressed: _fillDemoCredentials,
                        side: BorderSide(
                          color: theme.colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space24),

                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed(AppRoutes.register);
                          },
                          child: const Text(
                            'Sign Up',
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
