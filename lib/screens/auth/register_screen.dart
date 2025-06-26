import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shine/screens/auth/auth_screen.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/auth/auth_state.dart';
import '../../theme/app_constant.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/validators.dart';
import 'verification_code_screen.dart';

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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _agree = false;
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
    _confirmController.dispose();
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
          VerificationType.registration,
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

  String? _validateForm() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    final emailError = validateEmail(email);
    if (emailError != null) return emailError;

    final passwordError = validatePassword(password);
    if (passwordError != null) return passwordError;

    if (password != confirm) return 'Пароли не совпадают';

    return null;
  }

  Future<void> _register() async {
    final validationError = _validateForm();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    context.read<AuthCubit>().signUp(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  void _signInWithGoogle() {
    context.read<AuthCubit>().signInWithGoogle();
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
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
                const SizedBox(height: 32),
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
                    confirmController: _confirmController,
                    error: _error,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _AnimatedSection(
                  delay: 400,
                  child: _AgreementSection(
                    agree: _agree,
                    onChanged: (value) => setState(() => _agree = value),
                  ),
                ),
                const SizedBox(height: 16),
                _AnimatedSection(
                  delay: 600,
                  child: _RegisterButton(
                    agree: _agree,
                    isLoading: _isLoading,
                    onPressed: _register,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _AnimatedSection(
                  delay: 800,
                  child: _SocialSection(
                    isLoading: _isLoading,
                    onGoogleSignIn: _signInWithGoogle,
                  ),
                ),
                const Spacer(),
                _AnimatedSection(
                  delay: 1000,
                  child: _LoginSection(onLogin: _navigateToLogin),
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
        'Регистрация',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final String? error;

  const _FormSection({
    required this.emailController,
    required this.passwordController,
    required this.confirmController,
    required this.error,
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
          hint: 'Введите пароль',
          controller: passwordController,
          obscure: true,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'ПОВТОРИТЕ ПАРОЛЬ',
          hint: 'Повторите пароль',
          controller: confirmController,
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
      ],
    );
  }
}

class _AgreementSection extends StatelessWidget {
  final bool agree;
  final Function(bool) onChanged;

  const _AgreementSection({
    required this.agree,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: agree,
          onChanged: (value) => onChanged(value ?? false),
          shape: const CircleBorder(),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black87,
              ),
              children: [
                const TextSpan(text: 'Я согласен(-на) с условиями\n'),
                TextSpan(
                  text: 'Пользовательского соглашения',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _showTermsOfService(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showTermsOfService(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Пользовательское соглашение',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.termsOfService,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
  }
}

class _RegisterButton extends StatelessWidget {
  final bool agree;
  final bool isLoading;
  final VoidCallback onPressed;

  const _RegisterButton({
    required this.agree,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      tween: Tween<double>(begin: agree ? 1 : 0, end: agree ? 1 : 0),
      builder: (context, value, child) {
        final backgroundColor = Color.lerp(Colors.grey[300], Colors.black, value)!;
        final foregroundColor = Color.lerp(Colors.grey[600], Colors.white, value)!;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (agree && !isLoading) ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor: backgroundColor,
              disabledForegroundColor: foregroundColor,
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Зарегистрироваться'),
          ),
        );
      },
    );
  }
}

class _SocialSection extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onGoogleSignIn;

  const _SocialSection({
    required this.isLoading,
    required this.onGoogleSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: Text(
            'или войдите с помощью',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : onGoogleSignIn,
            icon: Image.asset('assets/images/google.png', width: 24, height: 24),
            label: const Text('Google'),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: const StadiumBorder(),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginSection extends StatelessWidget {
  final VoidCallback onLogin;

  const _LoginSection({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: Text(
            'Уже есть аккаунт?',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onLogin,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: const StadiumBorder(),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Войти'),
          ),
        ),
      ],
    );
  }
}