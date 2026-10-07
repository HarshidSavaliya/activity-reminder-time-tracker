import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/custom_snackbar.dart';

/// EditProfileDialog allows users to update their personal details and academic metadata.
class EditProfileDialog extends StatefulWidget {
  final UserModel user;

  const EditProfileDialog({super.key, required this.user});

  static Future<void> show(BuildContext context, UserModel user) {
    return showDialog(
      context: context,
      builder: (context) => EditProfileDialog(user: user),
    );
  }

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _collegeController;
  late TextEditingController _studentIdController;
  late TextEditingController _bioController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _usernameController = TextEditingController(text: widget.user.username);
    _collegeController = TextEditingController(text: widget.user.college);
    _studentIdController = TextEditingController(text: widget.user.studentId);
    _bioController = TextEditingController(text: widget.user.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _collegeController.dispose();
    _studentIdController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();

    final updated = widget.user.copyWith(
      name: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      college: _collegeController.text.trim(),
      studentId: _studentIdController.text.trim(),
      bio: _bioController.text.trim(),
    );

    final success = await auth.updateProfile(updated);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      CustomSnackbar.showSuccess(context, 'Profile updated successfully');
      Navigator.of(context).pop();
    } else {
      CustomSnackbar.showError(context, auth.errorMessage ?? 'Update failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppDimensions.borderRadiusMd),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Profile',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        AppTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          hintText: 'Your name',
                          prefixIcon: Icons.badge_outlined,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppDimensions.space12),
                        AppTextField(
                          controller: _usernameController,
                          label: 'Username',
                          hintText: 'e.g. alex_student',
                          prefixIcon: Icons.alternate_email_rounded,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Username is required';
                            }
                            if (val.trim().length < 3) {
                              return 'Username must be at least 3 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppDimensions.space12),
                        AppTextField(
                          controller: _collegeController,
                          label: 'Organization / Workplace / College',
                          hintText: 'e.g. Acme Corp, Studio, or University',
                          prefixIcon: Icons.business_outlined,
                        ),
                        const SizedBox(height: AppDimensions.space12),
                        AppTextField(
                          controller: _studentIdController,
                          label: 'Member / Account ID',
                          hintText: 'e.g. USR-2026',
                          prefixIcon: Icons.badge_rounded,
                        ),
                        const SizedBox(height: AppDimensions.space12),
                        AppTextField(
                          controller: _bioController,
                          label: 'Bio / Focus',
                          hintText: 'e.g. Focused on daily productivity & habits',
                          prefixIcon: Icons.info_outline_rounded,
                          maxLines: 2,
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
                      text: 'Save Changes',
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
