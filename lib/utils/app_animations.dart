// lib/utils/app_animations.dart
import 'package:flutter/material.dart';
import '../theme/app_constant.dart';

/// Класс для создания красивых переходов между экранами
class AppPageTransitions {

  /// Slide transition слева направо
  static PageRouteBuilder slideFromRight<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  /// Slide transition слева
  static PageRouteBuilder slideFromLeft<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(-1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  /// Slide transition снизу вверх
  static PageRouteBuilder slideFromBottom<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  /// Fade transition
  static PageRouteBuilder fadeTransition<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  /// Scale transition
  static PageRouteBuilder scaleTransition<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.elasticOut;
        var tween = Tween(begin: 0.8, end: 1.0).chain(
          CurveTween(curve: curve),
        );

        return ScaleTransition(
          scale: animation.drive(tween),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  /// Комбинированный переход с slide и fade
  static PageRouteBuilder slideAndFade<T>(Widget page, {Offset? begin}) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        final beginOffset = begin ?? const Offset(1.0, 0.0);

        var slideTween = Tween(begin: beginOffset, end: end).chain(
          CurveTween(curve: curve),
        );

        var fadeTween = Tween(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(slideTween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
    );
  }
}

/// Класс для создания анимированных виджетов
class AppAnimatedWidgets {

  /// Анимированное появление виджета с задержкой
  static Widget delayedFadeIn({
    required Widget child,
    required Duration delay,
    Duration duration = const Duration(milliseconds: 600),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Анимированное появление списка элементов
  static Widget staggeredList({
    required List<Widget> children,
    Duration itemDelay = const Duration(milliseconds: 100),
    Duration itemDuration = const Duration(milliseconds: 600),
  }) {
    return Column(
      children: children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;

        return delayedFadeIn(
          delay: itemDelay * index,
          duration: itemDuration,
          child: child,
        );
      }).toList(),
    );
  }

  /// Анимированный счетчик
  static Widget animatedCounter({
    required int count,
    TextStyle? textStyle,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: count),
      duration: duration,
      builder: (context, value, child) {
        return Text(
          value.toString(),
          style: textStyle ?? AppTextStyles.h2,
        );
      },
    );
  }

  /// Анимированная иконка с пульсацией
  static Widget pulsingIcon({
    required IconData icon,
    Color? color,
    double size = 24,
    Duration duration = const Duration(milliseconds: 1000),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.8, end: 1.0),
      duration: duration,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Icon(
            icon,
            color: color,
            size: size,
          ),
        );
      },
    );
  }

  /// Анимированный контейнер с изменением цвета
  static Widget colorTransition({
    required Widget child,
    required Color fromColor,
    required Color toColor,
    required bool isActive,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        begin: isActive ? fromColor : toColor,
        end: isActive ? toColor : fromColor,
      ),
      duration: duration,
      builder: (context, color, child) {
        return Container(
          color: color,
          child: child,
        );
      },
      child: child,
    );
  }

  /// Анимированная загрузка с точками
  static Widget loadingDots({
    Color color = AppColors.primary,
    double size = 8,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.4, end: 1.0),
              duration: Duration(milliseconds: 600 + (index * 200)),
              builder: (context, value, child) {
                return Container(
                  width: size,
                  height: size,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(value),
                    shape: BoxShape.circle,
                  ),
                );
              },
            );
          }),
        );
      },
    );
  }

  /// Анимированный прогресс бар
  static Widget animatedProgressBar({
    required double progress,
    Color? backgroundColor,
    Color? progressColor,
    double height = 4,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: progress),
      duration: duration,
      builder: (context, value, child) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.gray.withOpacity(0.3),
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: FractionallySizedBox(
            widthFactor: value,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: progressColor ?? AppColors.primary,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Анимированная волна
  static Widget waveAnimation({
    required Widget child,
    Duration duration = const Duration(milliseconds: 2000),
    double waveHeight = 20,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, waveHeight * (0.5 - (value * 0.5))),
          child: child,
        );
      },
      child: child,
    );
  }

  /// Анимированный рипл эффект
  static Widget rippleEffect({
    required Widget child,
    required VoidCallback onTap,
    Color rippleColor = AppColors.primary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: rippleColor.withOpacity(0.3),
        highlightColor: rippleColor.withOpacity(0.1),
        borderRadius: AppBorderRadius.s,
        child: child,
      ),
    );
  }

  /// Анимированное поле ввода с фокусом
  static Widget animatedInputField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    bool obscureText = false,
    Widget? suffixIcon,
    String? errorText,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool hasFocus = false;
        bool hasText = controller.text.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: AppBorderRadius.s,
            border: Border.all(
              color: hasFocus ? AppColors.primary : AppColors.gray.withOpacity(0.3),
              width: hasFocus ? 2 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: AppTextStyles.body,
            onChanged: (value) {
              setState(() {
                hasText = value.isNotEmpty;
              });
            },
            decoration: InputDecoration(
              labelText: label,
              hintText: hintText,
              errorText: errorText,
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(AppSpacing.s),
              labelStyle: AppTextStyles.hintAccent.copyWith(
                color: hasFocus ? AppColors.primary : AppColors.gray,
              ),
              hintStyle: AppTextStyles.hintMain,
              errorStyle: AppTextStyles.error,
            ),
          ),
        );
      },
    );
  }
}

/// Анимированный splash screen
class AnimatedSplashScreen extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final VoidCallback? onAnimationComplete;

  const AnimatedSplashScreen({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2000),
    this.onAnimationComplete,
  });

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: Duration(milliseconds: widget.duration.inMilliseconds ~/ 2),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: Duration(milliseconds: widget.duration.inMilliseconds ~/ 3),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _startAnimation();
  }

  void _startAnimation() async {
    await _fadeController.forward();
    await _scaleController.forward();

    if (widget.onAnimationComplete != null) {
      widget.onAnimationComplete!();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Анимированный индикатор состояния
class AnimatedStatusIndicator extends StatefulWidget {
  final String status;
  final Color color;
  final IconData icon;

  const AnimatedStatusIndicator({
    super.key,
    required this.status,
    required this.color,
    required this.icon,
  });

  @override
  State<AnimatedStatusIndicator> createState() => _AnimatedStatusIndicatorState();
}

class _AnimatedStatusIndicatorState extends State<AnimatedStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _opacityAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                borderRadius: AppBorderRadius.s,
                border: Border.all(
                  color: widget.color.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    color: widget.color,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    widget.status,
                    style: AppTextStyles.hintMain.copyWith(
                      color: widget.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}