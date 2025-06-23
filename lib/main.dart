// lib/main.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shine/blocs/auth/auth_cubit.dart';
import 'package:shine/blocs/auth/auth_state.dart';
import 'package:shine/blocs/role/role_cubit.dart';
import 'package:shine/blocs/role/role_state.dart';
import 'package:shine/blocs/onboarding/onboarding_cubit.dart' as onb;
import 'package:shine/blocs/wifi/wifi_cubit.dart';
import 'package:shine/screens/onboarding_screen.dart';
import 'package:shine/screens/roles/role_select.dart';
import 'package:shine/screens/saver_screen.dart';
import 'package:shine/permission_manager.dart';
import 'package:shine/theme/app_constant.dart';
import 'package:shine/services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

class ShineApp extends StatelessWidget {
  const ShineApp({super.key});
  

  @override
  Widget build(BuildContext context) {
    Future.microtask(() => PermissionManager.requestPermissions(context));
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
