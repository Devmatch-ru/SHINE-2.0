// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shine/screens/auth_screen.dart';
import 'blocs/auth/auth_cubit.dart';
import 'blocs/auth/auth_state.dart';
import 'blocs/role/role_cubit.dart';
import 'blocs/role/role_state.dart';
import 'blocs/onboarding/onboarding_cubit.dart';
import 'blocs/onboarding/onboarding_cubit.dart' as onb;
import 'screens/onboarding_screen.dart';
import 'screens/role_select.dart';
import 'screens/host_screen.dart';
import 'screens/client_screen.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  debugPaintBaselinesEnabled = false;
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit(AuthService.instance)),
        BlocProvider(create: (_) => OnboardingCubit()),
        BlocProvider(create: (_) => RoleCubit()),
      ],
      child: ShineApp(),
    ),
  );
}

class ShineApp extends StatelessWidget {
  const ShineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHINE',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          if (authState is AuthLoading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          } else if (authState is Unauthenticated) {
            return const LoginScreen();
          } else {
            return BlocBuilder<OnboardingCubit, onb.OnboardingState>(
              builder: (context, onbState) {
                if (onbState is onb.OnboardingRequired) {
                  return const OnboardingScreen();
                }
                // onboarding complete:
                return BlocBuilder<RoleCubit, RoleState>(
                  builder: (context, roleState) {
                    if (roleState is RoleInitial) {
                      return const RoleSelect();
                    } else if (roleState is RoleHost) {
                      // return HostScreen(); //TODO update host screen
                    } else if (roleState is RoleClient) {
                      // return ClientScreen(); //TODO update client screen
                    }
                    return const RoleSelect();
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
