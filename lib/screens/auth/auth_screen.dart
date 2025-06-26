import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shine/screens/auth/register_screen.dart';
import 'package:shine/screens/auth/verification_code_screen.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/auth/auth_state.dart';
import '../../models/user_model/user_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_constant.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_text_field.dart';
import '../test/HomeScreen.dart';

enum AuthErrorType {
  emailVerification,
  googleVerification,
  googleConflict,
  general,
}

class AuthErrorData {
  final AuthErrorType type;
  final String email;
  final String message;

  AuthErrorData({
    required this.type,
    required this.email,
    required this.message,
  });

  static AuthErrorData fromMessage(String message) {
    if (message.startsWith('email_verification_required:')) {
      return AuthErrorData(
        type: AuthErrorType.emailVerification,
        email: message.split(':')[1],
        message: message,
      );
    } else if (message.startsWith('google_verification_required:')) {
      return AuthErrorData(
        type: AuthErrorType.googleVerification,
        email: message.split(':')[1],
        message: message,
      );
    } else if (message.startsWith('google_conflict:')) {
      final parts = message.split(':');
      return AuthErrorData(
        type: AuthErrorType.googleConflict,
        email: parts.length > 1 ? parts[1] : '',
        message: parts.length > 2 ? parts.sublist(2).join(':') : 'Конфликт аккаунтов',
      );
    }

    return AuthErrorData(
      type: AuthErrorType.general,
      email: '',
      message: message,
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setupAuthListener() {
    context.read<AuthCubit>().stream.listen((state) {
      if (state is AuthError) {
        _handleAuthError(AuthErrorData.fromMessage(state.message));
      }
    });
  }

  void _handleAuthError(AuthErrorData errorData) {
    switch (errorData.type) {
      case AuthErrorType.emailVerification:
        _navigateToVerification(
          errorData.email,
          VerificationType.enterAccount,
              (email, _) => context.read<AuthCubit>().signIn(email, _passwordController.text),
        );
        break;
      case AuthErrorType.googleVerification:
        _navigateToVerification(
          errorData.email,
          VerificationType.googleVerification,
              (email, _) => context.read<AuthCubit>().completeGoogleSignIn(),
          skipCodeSending: true,
        );
        break;
      case AuthErrorType.googleConflict:
        _showGoogleConflictDialog(errorData);
        break;
      case AuthErrorType.general:
        setState(() => _error = errorData.message);
        break;
    }
  }

  void _navigateToVerification(
      String email,
      VerificationType type,
      Function(String, String?) onSuccess, {
        bool skipCodeSending = false,
      }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerificationCodeScreen(
          email: email,
          type: type,
          skipCodeSending: skipCodeSending,
          onSuccess: onSuccess,
        ),
      ),
    );
  }

  void _showGoogleConflictDialog(AuthErrorData errorData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Аккаунт уже существует'),
        content: Text(errorData.message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _emailController.text = errorData.email;
                _isLoading = false;
                _error = null;
              });
            },
            child: const Text('Войти через email'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isLoading = false;
                _error = null;
              });
            },
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  String _extractErrorText(Object e) {
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
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final emailError = validateEmail(email);
    final passwordError = validatePassword(password);

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
        email: email,
        password: password,
      ));

      if (mounted) {
        if (authResponse['success'] == true) {
          _navigateToVerification(
            email,
            VerificationType.enterAccount,
                (email, _) => context.read<AuthCubit>().signIn(email, password),
          );
        } else {
          setState(() => _error = authResponse['error'] ?? 'Ошибка авторизации');
        }
      }
    } catch (e) {
      setState(() => _error = _extractErrorText(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final emailError = validateEmail(email);

    if (emailError != null) {
      setState(() => _error = emailError);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ApiService();
      await api.sendCode(email);

      if (mounted) {
        _navigateToVerification(
          email,
          VerificationType.passwordReset,
              (_, __) {},
          skipCodeSending: true,
        );
      }
    } catch (e) {
      setState(() => _error = _extractErrorText(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _signInWithGoogle() {
    context.read<AuthCubit>().signInWithGoogle();
  }

  void _navigateToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _navigateToTest() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: BlocListener<AuthCubit, AuthState>(
            listener: (context, state) {
              if (state is AuthError) {
                _handleAuthError(AuthErrorData.fromMessage(state.message));
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
                _AnimatedSection(
                  delay: 0,
                  child: _HeaderSection(),
                ),
                const SizedBox(height: 32),
                _AnimatedSection(
                  delay: 200,
                  child: _FormSection(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    error: _error,
                    isLoading: _isLoading,
                    onSignIn: _signIn,
                    onResetPassword: _resetPassword,
                  ),
                ),
                const SizedBox(height: 24),
                _AnimatedSection(
                  delay: 400,
                  child: _SocialSection(
                    isLoading: _isLoading,
                    onGoogleSignIn: _signInWithGoogle,
                    onTestSignIn: _navigateToTest,
                  ),
                ),
                const Spacer(),
                _AnimatedSection(
                  delay: 600,
                  child: _RegisterSection(onRegister: _navigateToRegister),
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

class _AnimatedSection extends StatefulWidget {
  final int delay;
  final Widget child;

  const _AnimatedSection({
    required this.delay,
    required this.child,
  });

  @override
  State<_AnimatedSection> createState() => _AnimatedSectionState();
}

class _AnimatedSectionState extends State<_AnimatedSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _slideY;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    );
    _slideY = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _slideY.value),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _HeaderSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Вход в аккаунт',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String? error;
  final bool isLoading;
  final VoidCallback onSignIn;
  final VoidCallback onResetPassword;

  const _FormSection({
    required this.emailController,
    required this.passwordController,
    required this.error,
    required this.isLoading,
    required this.onSignIn,
    required this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextField(
          label: 'ВВЕДИТЕ EMAIL',
          hint: 'Ваш Email',
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'ВВЕДИТЕ ПАРОЛЬ',
          hint: 'Ваш пароль',
          controller: passwordController,
          obscure: true,
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.red,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: isLoading ? null : onResetPassword,
            child: Text('Забыли пароль?', style: AppTextStyles.body),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: isLoading ? null : onSignIn,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Войти'),
        ),
      ],
    );
  }
}

class _SocialSection extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onTestSignIn;

  const _SocialSection({
    required this.isLoading,
    required this.onGoogleSignIn,
    required this.onTestSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.s),
        Center(
          child: Text(
            'или войдите с помощью',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _SocialButton(
          icon: 'assets/images/google.png',
          label: 'Google',
          onPressed: isLoading ? null : onGoogleSignIn,
        ),
        const SizedBox(height: AppSpacing.xs),
        _SocialButton(
          icon: 'assets/images/google.png',
          label: 'Test Mode',
          onPressed: onTestSignIn,
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback? onPressed;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Image.asset(icon, width: 24, height: 24),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          shape: const StadiumBorder(),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

}

class _RegisterSection extends StatelessWidget {
  final VoidCallback onRegister;

  const _RegisterSection({required this.onRegister});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: Text(
            'Нет аккаунта?',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onRegister,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: const StadiumBorder(),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Зарегистрироваться'),
          ),
        ),

      ],
    );
  }
}