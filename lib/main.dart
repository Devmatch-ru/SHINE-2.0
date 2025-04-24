import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shine/blocs/auth/auth_state.dart';
import 'package:shine/blocs/role/role_state.dart';
import 'package:shine/screens/role_select.dart';
import 'blocs/auth/auth_cubit.dart';
import 'blocs/role/role_cubit.dart';
import 'screens/auth_screen.dart';
import 'screens/host_screen.dart';
import 'screens/client_screen.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit(AuthService.instance)),
        BlocProvider(create: (_) => RoleCubit()),
      ],
      child: ShineApp(),
    ),
  );
}

class ShineApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHINE',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          if (authState is AuthLoading) {
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          } else if (authState is Unauthenticated) {
            return AuthScreen();
          } else if (authState is Authenticated) {
            return BlocBuilder<RoleCubit, RoleState>(
              builder: (context, roleState) {
                if (roleState is RoleInitial) {
                  return RoleSelect();
                } else if (roleState is RoleHost) {
                  return HostScreen();
                } else if (roleState is RoleClient) {
                  return ClientScreen();
                }
                return RoleSelect();
              },
            );
          }
          return Container();
        },
      ),
    );
  }
}
