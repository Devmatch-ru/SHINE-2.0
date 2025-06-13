import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../theme/main_design.dart';
import '../../widgets/custom_text_field.dart';

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

  //url to user agreement TODO mb not necessary
  //final _agreementUrl = Uri.parse('https://');

  void _openAgreement() async {}

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
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Checkbox(
                    value: _agree,
                    onChanged: (v) => setState(() => _agree = v ?? false),
                    shape: const CircleBorder(),
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.black87),
                        children: [
                          const TextSpan(text: 'Я согласен(-на) с условиями\n'),
                          TextSpan(
                            text: 'Пользовательского соглашения',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black, // цвет ссылки
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = _openAgreement,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ElevatedButton.icon(
              //   icon: Image.asset('assets/images/google.png',
              //       width: 24, height: 24),
              //   label: const Text('Google Sign-In'),
              //   onPressed: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(builder: (_) => const GoogleTestScreen()),
              //     );
              //   },
              // ),
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
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Text('или войдите с помощью',
                    style: theme.textTheme.bodySmall),
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: () => context.read<AuthCubit>().signInWithGoogle(),
                icon: Image.asset('assets/images/google.png',
                    width: 24, height: 24),
                label: const Text('Google'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              // OutlinedButton.icon(
              //   onPressed: () async => await Navigator.push(
              //     context,
              //     MaterialPageRoute(
              //         builder: (_) => const PermissionsTestScreen()),
              //   ),
              //   icon: Image.asset('assets/images/google.png',
              //       width: 24, height: 24),
              //   label: const Text('Permision'),
              //   style: OutlinedButton.styleFrom(
              //     backgroundColor: Colors.white,
              //     shape: const StadiumBorder(),
              //     side: BorderSide.none,
              //     padding: const EdgeInsets.symmetric(vertical: 14),
              //   ),
              // ),OutlinedButton.icon(
              //   onPressed: () async => await Navigator.push(
              //     context,
              //     MaterialPageRoute(
              //         builder: (_) => const HostTipScreen()),
              //   ),
              //   icon: Image.asset('assets/images/google.png',
              //       width: 24, height: 24),
              //   label: const Text('Permision'),
              //   style: OutlinedButton.styleFrom(
              //     backgroundColor: Colors.white,
              //     shape: const StadiumBorder(),
              //     side: BorderSide.none,
              //     padding: const EdgeInsets.symmetric(vertical: 14),
              //   ),
              // ),
              const Spacer(),
              Center(
                  child: Text('Уже есть аккаунт?',
                      style: theme.textTheme.bodySmall)),
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
