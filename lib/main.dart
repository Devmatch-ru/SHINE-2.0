// lib/main.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shine/blocs/auth/auth_cubit.dart';
import 'package:shine/blocs/auth/auth_state.dart';
import 'package:shine/blocs/role/role_cubit.dart';
import 'package:shine/blocs/role/role_state.dart';
import 'package:shine/blocs/onboarding/onboarding_cubit.dart' as onb;
import 'package:shine/blocs/wifi/wifi_cubit.dart';
import 'package:shine/screens/onboarding_screen.dart';
import 'package:shine/screens/roles/role_select.dart';
import 'package:shine/screens/saver_screen.dart';
import 'package:shine/theme/main_design.dart';
import 'package:shine/services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermissions();
  debugPaintBaselinesEnabled = false;

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit(AuthService.instance)),
        BlocProvider(create: (_) => WifiCubit(connectivity: Connectivity())),
        BlocProvider(create: (_) => onb.OnboardingCubit()),
        BlocProvider(create: (_) => RoleCubit()),
      ],
      child: const ShineApp(),
    ),
  );
}

final GlobalKey<NavigatorState> _navigatiorKey = GlobalKey<NavigatorState>();

Future<void> requestPermissions() async {
  while (true) {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.locationWhenInUse,
    ].request();

    final allGranted = statuses.values.every((status) => status.isGranted);

    if (allGranted) break;

    final permanentlyDenied =
        statuses.values.any((status) => status.isPermanentlyDenied);

    if (permanentlyDenied) {
      final opened = await openAppSettings();
      if (!opened) break;
    } else {
      final shouldRetry = await showDialog<bool>(
        context: _navigatiorKey.currentContext!,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Разрешения'),
          content: const Text(
              'Для работы приложения необходимо разрешение на камеру, микрофон и геолокацию.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Выход'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );

      if (shouldRetry != true) break;
    }
  }
}

class ShineApp extends StatelessWidget {
  const ShineApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatiorKey,
      title: 'SHINE',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.primary,
          onPrimary: AppColors.primaryLight,
          secondary: AppColors.accentLight,
          onSecondary: Colors.white,
          error: AppColors.error,
          onError: Colors.white,
          background: AppColors.bgMain,
          onBackground: AppColors.primary,
          surface: Colors.white,
          onSurface: AppColors.primary,
        ),
        scaffoldBackgroundColor: AppColors.bgMain,
        textTheme: const TextTheme(
          displayLarge: AppTextStyles.h1,
          displayMedium: AppTextStyles.h2,
          titleLarge: AppTextStyles.lead,
          bodyLarge: AppTextStyles.body,
          bodySmall: AppTextStyles.hintAccent,
          bodyMedium: AppTextStyles.hintMain,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.primaryLight,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s, vertical: AppSpacing.m),
          border: OutlineInputBorder(
            borderRadius: AppBorderRadius.m,
            borderSide: BorderSide.none,
          ),
          hintStyle: AppTextStyles.hintMain,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 32,
            color: AppColors.primary,
            fontWeight: FontWeight.w400,
          ),
          iconTheme: IconThemeData(color: AppColors.primary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.primaryLight,
            shape: RoundedRectangleBorder(
              borderRadius: AppBorderRadius.xs,
            ),
            textStyle: const TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 17,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.s,
            ),
          ),
        ),
      ),
      home: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          if (authState is AuthLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (authState is Unauthenticated) {
            return const SaverScreen();
          }

          if (authState is Authenticated) {
            return BlocBuilder<onb.OnboardingCubit, onb.OnboardingState>(
              builder: (context, onbState) {
                if (onbState is onb.OnboardingRequired) {
                  return const OnboardingScreen();
                }
                return BlocBuilder<RoleCubit, RoleState>(
                  builder: (context, roleState) {
                    return const RoleSelectScreen();
                  },
                );
              },
            );
          }

          return const SaverScreen();
        },
      ),
    );
  }
}
