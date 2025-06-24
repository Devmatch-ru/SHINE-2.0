import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../models/user_model/user_model.dart';
import '../../theme/app_constant.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/validators.dart';
import '../../services/api_service.dart';
import 'verification_code_screen.dart';
import 'register_screen.dart';
import '../../blocs/auth/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  String? _error;

  @override
  void initState() {
    super.initState();
    context.read<AuthCubit>().stream.listen((state) {
      if (state is AuthError && state.message == 'google_verification_required') {
        _handleGoogleVerification();
      }
    });
  }

  void _handleGoogleVerification() async {
    if (_email.text.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerificationCodeScreen(
            email: _email.text.trim(),
            type: VerificationType.registration,
            onSuccess: (email, _) {
              context.read<AuthCubit>().signInWithGoogle();
            },
          ),
        ),
      );
    }
  }

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

  Future<void> _resetPassword() async {
    final emailError = validateEmail(_email.text.trim());
    if (emailError != null) {
      setState(() => _emailError = emailError);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ApiService();
      await api.sendCode(_email.text.trim());

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerificationCodeScreen(
              email: _email.text.trim(),
              type: VerificationType.passwordReset,
              skipCodeSending: true,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _emailError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _signInWithGoogle() {
    context.read<AuthCubit>().signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: BlocListener<AuthCubit, AuthState>(
            listener: (context, state) {
              if (state is AuthError) {
                if (state.message == 'google_verification_required') {
                  _handleGoogleVerification();
                } else {
                  setState(() => _error = state.message);
                }
              } else if (state is AuthLoading) {
                setState(() => _isLoading = true);
              } else {
                setState(() => _isLoading = false);
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Center(
                  child: Text(
                    'Вход в аккаунт',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 32),
                CustomTextField(
                  label: 'ВВЕДИТЕ EMAIL',
                  hint: 'Ваш Email',
                  controller: _email,
                  errorText: _emailError,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'ВВЕДИТЕ ПАРОЛЬ',
                  hint: 'Ваш пароль',
                  controller: _password,
                  obscure: true,
                  errorText: _passwordError,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    child: Text(
                      'Забыли пароль?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Войти'),
                ),
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: Text(
                    'или войдите с помощью',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  icon: Image.asset(
                    'assets/images/google.png',
                    width: 24,
                    height: 24,
                  ),
                  label: const Text('Google'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const Spacer(),
                Center(
                  child: Text(
                    'Нет аккаунта?',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Зарегистрироваться'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}