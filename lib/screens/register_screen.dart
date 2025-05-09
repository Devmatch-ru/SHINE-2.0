import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_cubit.dart';
import '../widgets/custom_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _agree = false;

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
                  'Регистрация',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 32),
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
              const SizedBox(height: 16),
              CustomTextField(
                label: 'ПОВТОРИТЕ ПАРОЛЬ',
                hint: 'Повторите пароль',
                controller: _confirm,
                obscure: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _agree,
                    onChanged: (v) => setState(() => _agree = v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'Я согласен(-на) с условиями\nПользовательского соглашения',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _agree
                    ? () => context.read<AuthCubit>().signUp(
                          _email.text,
                          _password.text,
                        )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Зарегистрироваться'),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text('или войдите с помощью', style: theme.textTheme.bodySmall),
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
              Center(child: Text('Уже есть аккаунт?', style: theme.textTheme.bodySmall)),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Войти'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}