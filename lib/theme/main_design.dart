import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF000000);
  static const Color primaryLight = Color(0xFFFFFFFF);
  static const Color premmarylight = Color(0xFFDBECF9);
  static const Color overlayLight = Color(0x80FFFFFF);
  static const Color bgMain = Color(0xFFF4F5F7);
  static const Color gray = Color(0xFF8E8E93);
  static const Color accentLight = Color(0xFFDBECF9);
  static const Color error = Color(0xFFF44336);
  static const Color shadow = Color(0x1A000000);
}
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
}

class AppTextStyles {
  static const String fontFamily = 'ProximaNova';

  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w400,
    decoration: TextDecoration.none,
    color: AppColors.primary,
  );
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w400,
    decoration: TextDecoration.none,
    color: AppColors.primary,
  );
  static const TextStyle lead = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    decoration: TextDecoration.none,
    color: AppColors.primary,
  );
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    decoration: TextDecoration.none,
    color: AppColors.primary,
  );
  static const TextStyle hintAccent = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.0,
    color: AppColors.gray,
    decoration: TextDecoration.none,
  );
  static const TextStyle hintMain = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.gray,
    decoration: TextDecoration.none,
  );
}

class AppSpacing {
  static const double xs = 8;
  static const double s  = 16;
  static const double m  = 20;
  static const double l  = 24;
  static const double xl = 32;
  static const double xxl= 60;
}
class IconSize {
  static const double xs = 8;
  static const double s  = 16;
  static const double m  = 20;
  static const double l  = 24;
  static const double xl = 32;
  static const double xxl= 60;
}

class AppBorderRadius {
  static const BorderRadius xs = BorderRadius.all(Radius.circular(8));
  static const BorderRadius s  = BorderRadius.all(Radius.circular(10));
  static const BorderRadius m  = BorderRadius.all(Radius.circular(20));
  static const BorderRadius l  = BorderRadius.all(Radius.circular(24));
}
