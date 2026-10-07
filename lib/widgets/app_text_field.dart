import 'package:flutter/material.dart';
import '../core/constants/app_dimensions.dart';

/// AppTextField provides a standardized, keyboard-safe, accessible input component.
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? initialValue;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;
  final int maxLines;
  final int? minLines;
  final TextCapitalization textCapitalization;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.initialValue,
    this.prefixIcon,
    this.suffix,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget? suffixWidget = widget.suffix;
    if (widget.isPassword) {
      suffixWidget = IconButton(
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: AppDimensions.iconSizeSm + 2,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        onPressed: () {
          setState(() {
            _obscured = !_obscured;
          });
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
        ],
        TextFormField(
          controller: widget.controller,
          initialValue: widget.initialValue,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          onTap: widget.onTap,
          readOnly: widget.readOnly,
          autofocus: widget.autofocus,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          minLines: widget.minLines,
          textCapitalization: widget.textCapitalization,
          style: TextStyle(
            fontSize: 15,
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: widget.prefixIcon != null
                ? Icon(
                    widget.prefixIcon,
                    size: AppDimensions.iconSizeSm + 2,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  )
                : null,
            suffixIcon: suffixWidget,
          ),
        ),
      ],
    );
  }
}
