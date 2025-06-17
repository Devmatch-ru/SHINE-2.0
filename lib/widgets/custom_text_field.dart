import 'package:flutter/material.dart';
import '../theme/main_design.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final String hint;
  final bool obscure;
  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final TextInputType? keyboardType;
  final Color? backgroundColor;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.enabled = true,
    this.errorText,
    this.keyboardType,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
          child: Text(
            label,
            style: AppTextStyles.hintAccent.copyWith(
              color: AppColors.gray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          obscureText: obscure,
          enabled: enabled,
          keyboardType: keyboardType,
          style: AppTextStyles.body.copyWith(
            color: errorText != null ? AppColors.error : AppColors.primary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.body.copyWith(
              color: AppColors.gray,
            ),
            filled: true,
            fillColor: backgroundColor ?? AppColors.primaryLight,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s,
              vertical: AppSpacing.m,
            ),
            border: OutlineInputBorder(
              borderRadius: AppBorderRadius.s,
              borderSide: BorderSide.none,
            ),
            errorText: errorText,
            errorStyle: AppTextStyles.error,
            errorBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.s,
              borderSide: const BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.s,
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
