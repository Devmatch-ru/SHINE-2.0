import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shine/screens/roles/role_select.dart';
import 'package:shine/permission_manager.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../theme/main_design.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/validators.dart';
import '../../services/api_service.dart';
import '../../models/user_model/user_model.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'verification_code_screen.dart';
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLoading = false;
  String? _error;

  String extractErrorText(Object e) {
    var text = e.toString();

    if (text.contains('"error":')) {
      final errorStart = text.indexOf('"error":') + 8;
      final errorEnd = text.indexOf('"', errorStart);
      if (errorEnd > errorStart) {
        return text.substring(errorStart, errorEnd);
      }
    }

    text = text
        .replaceAll('Exception: ', '')
        .replaceAll('Network error: ', '')
        .replaceAll('Request failed with status: ', '');

    if (text.contains('Body:')) {
      try {
        final bodyStart = text.indexOf('Body:') + 5;
        final jsonStr = text.substring(bodyStart).trim();
        final Map<String, dynamic> response = json.decode(jsonStr);
        if (response.containsKey('error')) {
          return response['error'].toString();
        }
      } catch (_) {}
    }

    return text;
  }

  Future<void> _signIn() async {
    final emailError = validateEmail(_email.text.trim());
    final passwordError = validatePassword(_password.text);

    if (emailError != null) {
      setState(() => _error = emailError);
      return;
    }
    if (passwordError != null) {
      setState(() => _error = passwordError);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ApiService();
      final authResponse = await api.authenticate(UserModel(
        email: _email.text.trim(),
        password: _password.text,
      ));

      if (mounted) {
        if (authResponse['success'] == true) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VerificationCodeScreen(
                email: _email.text.trim(),
                type: VerificationType.enterAccount,
                onSuccess: (email, _) {
                  context.read<AuthCubit>().signIn(
                        email,
                        _password.text,
                      );
                },
              ),
            ),
          );
        } else {
          setState(
              () => _error = authResponse['error'] ?? 'Ошибка авторизации');
        }
      }
    } catch (e) {
      setState(() => _error = extractErrorText(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Future.microtask(() => PermissionManager.requestPermissions(context));
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
                    errorText: _error,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen()),
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
              const SizedBox(height: AppSpacing.l),
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Войти',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
              const SizedBox(height: AppSpacing.s),
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Center(
                  child: Text('или войдите с помощью',
                      style: theme.textTheme.bodySmall),
                ),
              ),
              // const SocialAuthButton(),
              const Spacer(),
              Center(
                  child:
                      Text('Нет аккаунта?', style: theme.textTheme.bodySmall)),
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
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
