import 'package:flutter/material.dart';
import 'colors.dart';

class AppTextStyles {
  static const String fontFamily = 'ProximaNova';

  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w400,
    decoration: TextDecoration.none,
    color: AppColors.primary,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w400,
    decoration: TextDecoration.none,
    color: AppColors.primary,
    height: 1.3,
  );

  static const TextStyle lead = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    decoration: TextDecoration.none,
    color: AppColors.primary,
    height: 1.4,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    decoration: TextDecoration.none,
    color: AppColors.primary,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    decoration: TextDecoration.none,
    color: AppColors.primary,
    height: 1.4,
  );

  static const TextStyle hintAccent = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.0,
    color: AppColors.gray,
    decoration: TextDecoration.none,
    height: 1.2,
  );

  static const TextStyle hintMain = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.gray,
    decoration: TextDecoration.none,
    height: 1.4,
  );

  static const TextStyle error = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.error,
    decoration: TextDecoration.none,
    height: 1.2,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.gray,
    decoration: TextDecoration.none,
    height: 1.2,
  );

  // Анимированные стили для особых случаев
  static TextStyle getAnimatedStyle({
    required TextStyle baseStyle,
    Color? color,
    FontWeight? fontWeight,
    double? fontSize,
  }) {
    return baseStyle.copyWith(
      color: color,
      fontWeight: fontWeight,
      fontSize: fontSize,
    );
  }
}