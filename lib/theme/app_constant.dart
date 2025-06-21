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
  static const TextStyle error = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.error,
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

class AppStrings {
  static const String termsOfService = '''
  Данное пользовательское соглашение (далее — Соглашение) регулирует отношения между Evgenii Serdiuk, далее — Разработчик, и пользователем мобильного приложения Shine Remote Camera, далее — Пользователь.Используя приложение Shine Remote Camera, Пользователь соглашается с условиями данного Соглашения. Если Пользователь не согласен с условиями Соглашения, ему следует прекратить использование приложения.
  1. Описание сервиса
  Приложение Shine Remote Camera предоставляет возможность подключаться к другим устройствам для удалённой съёмки.
  2. Права и обязанности сторон
  2.1. Разработчик обязуется обеспечить работоспособность приложения в соответствии с его функциональными возможностями.
  2.2. Пользователь обязуется использовать приложение только в законных целях, не нарушая права и свободы третьих лиц.
  2.3. Разработчик также обязуется выпускать необходимые обновления приложения для обеспечения его работоспособности на обновленных версиях операционных систем Android и iOS, а также для внедрения нового функционала.
  3. Интеллектуальная собственность
  Все права на приложение, включая программный код, дизайн, тексты, графика и другие элементы, принадлежат Разработчику. Не допускается копирование, распространение или модификация приложения без письменного разрешения Разработчика.
  4. Ответственность
  Разработчик не несет ответственности за любой прямой или косвенный ущерб, понесенный Пользователем или третьими лицами в результате использования или невозможности использования приложения.
  5. Конфиденциальность
  Разработчик обязуется не раскрывать личную информацию Пользователя, полученную в ходе использования приложения, без согласия Пользователя, за исключением случаев, предусмотренных законом.
  6. Изменения в Соглашении
  Разработчик оставляет за собой право вносить изменения в Соглашение в любое время без предварительного уведомления Пользователя. Новая версия Соглашения вступает в силу с момента ее опубликования в приложении или на официальном сайте Разработчика.
  7. Заключительные положения
  7.1. Настоящее Соглашение является юридически обязывающим документом между Пользователем и Разработчиком и регулирует условия использования приложения.
  7.2. Все споры и разногласия, возникающие в связи с исполнением настоящего Соглашения, решаются путем переговоров. В случае невозможности достижения согласия споры подлежат рассмотрению в порядке, установленном законодательством страны Разработчика.
  8. Обратная связь
  В случае возникновения вопросов, предложений или необходимости технической поддержки, Пользователи могут обращаться в службу поддержки приложения Shine Remote Camera по электронной почте: helpmewhynot69@gmail.com. Команда поддержки приложения обязуется предоставлять оперативную помощь и консультации по всем интересующим вопросам, связанным с использованием приложения.''';
}

