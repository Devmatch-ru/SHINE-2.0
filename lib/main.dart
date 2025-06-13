// lib/main.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shine/blocs/auth/auth_cubit.dart';
import 'package:shine/blocs/auth/auth_state.dart';
import 'package:shine/blocs/broadcaster/broadcaster_cubit.dart';
import 'package:shine/blocs/receiver/receiver_cubit.dart';
import 'package:shine/blocs/role/role_cubit.dart';
import 'package:shine/blocs/role/role_state.dart';
import 'package:shine/blocs/onboarding/onboarding_cubit.dart' as onb;
import 'package:shine/blocs/wifi/wifi_cubit.dart';
import 'package:shine/screens/auth/auth_screen.dart';
import 'package:shine/screens/onboarding_screen.dart';
import 'package:shine/screens/roles/role_select.dart';
import 'package:shine/theme/main_design.dart';
import 'package:shine/services/auth_service.dart';
import 'package:shine/utils/broadcaster_manager.dart';
import 'package:shine/utils/receiver_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  debugPaintBaselinesEnabled = false;

  final broadcasterManager = await BroadcasterManager.create(
    onStateChange: () {}, // Empty callback for state changes
    onError: (error) => debugPrint('Broadcaster error: $error'),
    onMediaCaptured: (media) => debugPrint('Media captured: ${media.path}'),
  );

  final receiverManager = ReceiverManager();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit(AuthService.instance)),
        BlocProvider(create: (_) => WifiCubit(connectivity: Connectivity())),
        BlocProvider(create: (_) => onb.OnboardingCubit()),
        BlocProvider(create: (_) => RoleCubit()),
        BlocProvider(
          create: (_) => BroadcasterCubit(
            broadcasterManager: broadcasterManager,
          ),
        ),
        BlocProvider(
          create: (_) => ReceiverCubit(
            receiverManager: receiverManager,
          ),
        ),
      ],
      child: const ShineApp(),
    ),
  );
}

Future<void> _requestPermissions() async {
  final statuses = await [
    Permission.camera,
    Permission.nearbyWifiDevices,
    Permission.locationWhenInUse,
    Permission.storage,
  ].request();

  statuses.forEach((permission, status) {
    if (status.isDenied || status.isPermanentlyDenied) {
      debugPrint('Permission $permission was denied');
      if (permission == Permission.nearbyWifiDevices) {
        debugPrint('NEARBY_WIFI_DEVICES denied, Wi-Fi detection may fail');
      }
    }
  });
}

class ShineApp extends StatelessWidget {
  const ShineApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
          } else if (authState is Unauthenticated) {
            return const LoginScreen();
          } else {
            return BlocBuilder<onb.OnboardingCubit, onb.OnboardingState>(
              builder: (context, onbState) {
                if (onbState is onb.OnboardingRequired) {
                  return const OnboardingScreen();
                }
                // onboarding complete:
                return BlocBuilder<RoleCubit, RoleState>(
                  builder: (context, roleState) {
                    if (roleState is RoleInitial) {
                      return const RoleSelectScreen();
                    }
                    // else if (roleState is RoleHost) {
                    //   return const HostScreen();
                    // } else if (roleState is RoleClient) {
                    //   return const ClientScreen();
                    // }
                    return const RoleSelectScreen();
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}
