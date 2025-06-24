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
  static const Color blur = Color(0xB3000000);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // Градиенты для анимаций
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF333333)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [premmarylight, Color(0xFFE8F4FD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}