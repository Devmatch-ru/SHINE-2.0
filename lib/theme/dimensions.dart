import 'package:flutter/material.dart';

class AppSpacing {
  static const double xs = 8;
  static const double s = 16;
  static const double m = 20;
  static const double l = 24;
  static const double xl = 32;
  static const double xxl = 60;
}

class IconSize {
  static const double xs = 8;
  static const double s = 16;
  static const double m = 20;
  static const double l = 24;
  static const double xl = 32;
  static const double xxl = 60;
}

class AppBorderRadius {
  static const BorderRadius xs = BorderRadius.all(Radius.circular(8));
  static const BorderRadius s = BorderRadius.all(Radius.circular(10));
  static const BorderRadius m = BorderRadius.all(Radius.circular(20));
  static const BorderRadius l = BorderRadius.all(Radius.circular(24));
  static const BorderRadius xl = BorderRadius.all(Radius.circular(32));
}

class AppShadows {
  static const List<BoxShadow> light = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x15000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> heavy = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];
}
