import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../theme/main_design.dart';
import '../../utils/device_enumeration_sample.dart';
import '../../utils/get_user_media_sample.dart';
import '../../widgets/custom_text_field.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Вход в аккаунт',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    label: 'ВВЕДИТЕ EMAIL',
                    hint: 'Ваш Email',
                    controller: _email,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'ВВЕДИТЕ ПАРОЛЬ',
                    hint: 'Введите пароль',
                    controller: _password,
                    obscure: true,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ForgotPasswordScreen()),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      child: const Text(
                        'Забыли пароль?',
                        style: TextStyle(color: Colors.blueGrey),
                      ),
                    ),
                  ),
                ],
              ),


              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.read<AuthCubit>().signIn(
                  _email.text,
                  _password.text,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Войти',
                  style: TextStyle(color: Colors.white),
                ),
              ),

              const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
              child:
              Center(
                child: Text('или войдите с помощью', style: theme.textTheme.bodySmall),
              ),
          ),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: () => context.read<AuthCubit>().signInWithGoogle(),
                icon: Image.asset('assets/images/google.png', width: 24, height: 24),
                label: const Text('Google'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const Spacer(),
              Center(child: Text('Нет аккаунта?', style: theme.textTheme.bodySmall)),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Зарегистрироваться',
                  style: TextStyle(color: Colors.black),
                ),

              ),OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DeviceEnumerationSample()),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Зарегистрироваться',
                  style: TextStyle(color: Colors.black),
                ),

              ),
              //test

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}