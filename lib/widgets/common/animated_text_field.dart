import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_constant.dart';

class AnimatedTextField extends StatefulWidget {
  final String label;
  final String hint;
  final bool obscure;
  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final TextInputType? keyboardType;
  final Color? backgroundColor;
  final List<TextInputFormatter>? inputFormatters;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLines;
  final int? maxLength;
  final Widget? suffixIcon;
  final Widget? prefixIcon;

  const AnimatedTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.enabled = true,
    this.errorText,
    this.keyboardType,
    this.backgroundColor,
    this.inputFormatters,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.maxLength,
    this.suffixIcon,
    this.prefixIcon,
  });

  @override
  State<AnimatedTextField> createState() => _AnimatedTextFieldState();
}

class _AnimatedTextFieldState extends State<AnimatedTextField>
    with TickerProviderStateMixin {
  late AnimationController _focusController;
  late AnimationController _errorController;
  late Animation<double> _focusAnimation;
  late Animation<double> _errorAnimation;
  late Animation<Color?> _borderColorAnimation;

  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();

    _focusController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _errorController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _focusAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _focusController, curve: Curves.easeInOut),
    );

    _errorAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _errorController, curve: Curves.elasticOut),
    );

    _borderColorAnimation = ColorTween(
      begin: Colors.transparent,
      end: AppColors.primary,
    ).animate(_focusController);

    _focusNode.addListener(_onFocusChange);

    if (widget.errorText != null) {
      _errorController.forward();
    }
  }

  @override
  void didUpdateWidget(AnimatedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.errorText != oldWidget.errorText) {
      if (widget.errorText != null) {
        _errorController.forward();
      } else {
        _errorController.reverse();
      }
    }
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });

    if (_isFocused) {
      _focusController.forward();
    } else {
      _focusController.reverse();
      _hideKeyboard();
    }
  }

  void _hideKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _focusController.dispose();
    _errorController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_focusAnimation, _errorAnimation]),
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: AppTextStyles.hintAccent.copyWith(
                  color: _isFocused
                      ? AppColors.primary
                      : widget.errorText != null
                      ? AppColors.error
                      : AppColors.gray,
                  fontWeight: _isFocused ? FontWeight.w600 : FontWeight.w500,
                ),
                child: Text(widget.label),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? AppColors.primaryLight,
                  borderRadius: AppBorderRadius.s,
                  border: Border.all(
                    color: _borderColorAnimation.value ?? Colors.transparent,
                    width: _isFocused ? 2 : 1,
                  ),
                  boxShadow: _isFocused
                      ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                      : null,
                ),
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  obscureText: widget.obscure,
                  enabled: widget.enabled,
                  keyboardType: widget.keyboardType,
                  inputFormatters: widget.inputFormatters,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  maxLines: widget.maxLines,
                  maxLength: widget.maxLength,
                  style: AppTextStyles.body.copyWith(
                    color: widget.errorText != null ? AppColors.error : AppColors.primary,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: AppTextStyles.body.copyWith(color: AppColors.gray),
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s,
                      vertical: AppSpacing.m,
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    prefixIcon: widget.prefixIcon,
                    suffixIcon: widget.suffixIcon,
                  ),
                ),
              ),
            ),
            if (widget.errorText != null)
              Transform.translate(
                offset: Offset(0, _errorAnimation.value * 4 - 4),
                child: Opacity(
                  opacity: _errorAnimation.value,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.s,
                      top: AppSpacing.xs / 2,
                    ),
                    child: Text(
                      widget.errorText!,
                      style: AppTextStyles.error,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}