import 'package:flutter/material.dart';
import '../theme/main_design.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final String hint;
  final bool obscure;
  final TextEditingController controller;
  final bool enabled;
  final String? errorText;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.enabled = true,
    this.errorText,
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
          style: AppTextStyles.body.copyWith(
            color: AppColors.primary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.body.copyWith(
              color: AppColors.gray,
            ),
            filled: true,
            fillColor: AppColors.primaryLight,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s,
              vertical: AppSpacing.m,
            ),
            border: OutlineInputBorder(
              borderRadius: AppBorderRadius.s,
              borderSide: BorderSide.none,
            ),
            errorText: errorText,
          ),
        ),
      ],
    );
  }
}