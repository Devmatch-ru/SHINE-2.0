import 'package:flutter/material.dart';
import 'dimensions.dart';

class AppIcons {
  static const _basePath = 'assets/icons';

  static Widget settings({double size = IconSize.xl}) => Image.asset(
    '$_basePath/settings.png',
    width: size,
    height: size,
  );

  static Widget profile({double size = IconSize.xl}) => Image.asset(
    '$_basePath/profile.png',
    width: size,
    height: size,
  );

  static Widget wifi1({double size = IconSize.xl}) => Image.asset(
    '$_basePath/wifi1.png',
    width: size,
    height: size,
  );

  static Widget wifi2({double size = IconSize.xl}) => Image.asset(
    '$_basePath/wifi2.png',
    width: size,
    height: size,
  );

  // Анимированные иконки
  static Widget animatedIcon({
    required Widget icon,
    required AnimationController controller,
    double size = IconSize.xl,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: controller.value * 2.0 * 3.14159,
          child: SizedBox(
            width: size,
            height: size,
            child: icon,
          ),
        );
      },
    );
  }
}
