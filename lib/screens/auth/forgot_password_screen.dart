import 'package:flutter/material.dart';
import '../../widgets/custom_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _stage = 'email';
  String _errorMessage = '';

  void _nextStage() {
    setState(() {
      if (_stage == 'email' && _emailController.text.isNotEmpty) {
        _stage = 'new_password';
        _newPasswordController.text = 'Afdpdjfk@';
        _confirmPasswordController.text = '**********';
      } else if (_stage == 'new_password' && _newPasswordController.text.isNotEmpty) {
        _stage = 'confirm_password';
      } else if (_stage == 'confirm_password' && _newPasswordController.text == _confirmPasswordController.text) {
        _stage = 'success';
      } else {
        _errorMessage = 'Пароли не совпадают';
      }
    });
  }

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
                  _stage == 'email' ? 'Забыли пароль?' : 'Вход в аккаунт',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 32),
              if (_stage == 'email') ...[
                Center(
                  child: Text(
                    'Введите email и мы пришлём письмо для сброса пароля',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'ВВЕДИТЕ EMAIL',
                  hint: 'Ваш Email',
                  controller: _emailController,
                ),
              ],
              if (_stage == 'new_password') ...[
                CustomTextField(
                  label: 'ВВЕДИТЕ EMAIL',
                  hint: 'Ваш Email',
                  controller: _emailController,
                  enabled: false,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'ВВЕДИТЕ ПАРОЛЬ',
                  hint: 'Введите пароль',
                  controller: _newPasswordController,
                  obscure: true,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'ПОВТОРИТЕ ПАРОЛЬ',
                  hint: 'Повторите пароль',
                  controller: _confirmPasswordController,
                  obscure: true,
                ),
              ],
              if (_stage == 'confirm_password') ...[
                CustomTextField(
                  label: 'ВВЕДИТЕ ПАРОЛЬ',
                  hint: 'Новый пароль',
                  controller: _newPasswordController,
                  obscure: true,
                  enabled: false,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'ПОВТОРИТЕ ПАРОЛЬ',
                  hint: 'Повторите пароль',
                  controller: _confirmPasswordController,
                  obscure: true,
                  errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _nextStage,
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
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}