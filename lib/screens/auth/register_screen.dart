import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../theme/main_design.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/validators.dart';
import '../../services/api_service.dart';
import 'verification_code_screen.dart';
import '../../models/user_model/user_model.dart';

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
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  //url to user agreement TODO mb
  //final _agreementUrl = Uri.parse('https://');


  Future<void> _register() async {
    // Валидация
    final emailError = validateEmail(_email.text.trim());
    final passwordError = validatePassword(_password.text);
    final confirmError =
        _password.text != _confirm.text ? 'Пароли не совпадают' : null;

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmError = confirmError;
    });

    if (emailError != null || passwordError != null || confirmError != null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ApiService();
      final response = await api.register(UserModel(
        email: _email.text.trim(),
        password: _password.text,
      ));

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerificationCodeScreen(
              email: _email.text.trim(),
              type: VerificationType.registration,
              onSuccess: (email, _) {
                context.read<AuthCubit>().signIn(
                      email,
                      _password.text,
                    );
              },
            ),
          ),
        );
      }
    } catch (e) {
      final error = e.toString().replaceFirst('Exception: ', '');
      if (error.contains('необходимо подтвердить email')) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VerificationCodeScreen(
                email: _email.text.trim(),
                type: VerificationType.registration,
                onSuccess: (email, _) {
                  context.read<AuthCubit>().signIn(
                        email,
                        _password.text,
                      );
                },
              ),
            ),
          );
        }
      } else {
        setState(() => _emailError = error);
      }
    } finally {
      setState(() => _isLoading = false);
    }
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
                  'Регистрация',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 32),
              CustomTextField(
                label: 'ВВЕДИТЕ EMAIL',
                hint: 'Ваш Email',
                controller: _email,
                errorText: _emailError,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'ВВЕДИТЕ ПАРОЛЬ',
                hint: 'Введите пароль',
                controller: _password,
                obscure: true,
                errorText: _passwordError,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'ПОВТОРИТЕ ПАРОЛЬ',
                hint: 'Повторите пароль',
                controller: _confirm,
                obscure: true,
                errorText: _confirmError,
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
                              color: Colors.black,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20)),
                                  ),
                                  builder: (context) =>
                                      DraggableScrollableSheet(
                                    initialChildSize: 0.9,
                                    minChildSize: 0.5,
                                    maxChildSize: 0.9,
                                    expand: false,
                                    builder: (context, scrollController) {
                                      return DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.background,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(20)),
                                        ),
                                        child: SingleChildScrollView(
                                          controller: scrollController,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Center(
                                                child: Container(
                                                  width: 40,
                                                  height: 4,
                                                  margin: const EdgeInsets.only(
                                                      bottom: 16),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[400],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            2),
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                'Пользовательское соглашение',
                                                style: theme
                                                    .textTheme.titleLarge
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                AppStrings.termsOfService,
                                                style: theme
                                                    .textTheme.bodyMedium
                                                    ?.copyWith(
                                                  height: 1.5,
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                tween:
                    Tween<double>(begin: _agree ? 1 : 0, end: _agree ? 1 : 0),
                builder: (context, value, child) {
                  final backgroundColor =
                      Color.lerp(Colors.grey[300], Colors.black, value)!;
                  final foregroundColor =
                      Color.lerp(Colors.grey[600], Colors.white, value)!;

                  return ElevatedButton(
                    onPressed: (_agree && !_isLoading) ? _register : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: backgroundColor,
                      foregroundColor: foregroundColor,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      disabledBackgroundColor: backgroundColor,
                      disabledForegroundColor: foregroundColor,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Зарегистрироваться'),
                  );
                },
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
