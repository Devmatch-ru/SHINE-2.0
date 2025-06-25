import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/api_service.dart';
import '../../theme/app_constant.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../roles/role_select.dart';
import 'reset_password_screen.dart';
import '../../blocs/onboarding/onboarding_cubit.dart' as onb;
import '../../blocs/role/role_cubit.dart';

enum VerificationType {
  registration,
  passwordReset,
  accountDeletion,
  enterAccount,
  googleVerification,
}

class VerificationCodeScreen extends StatefulWidget {
  final String email;
  final String? password;
  final VerificationType type;
  final Function(String email, String? password)? onSuccess;
  final bool skipCodeSending;

  const VerificationCodeScreen({
    super.key,
    required this.email,
    this.password,
    required this.type,
    this.onSuccess,
    this.skipCodeSending = false,
  });

  @override
  State<VerificationCodeScreen> createState() => _VerificationCodeScreenState();
}

class _VerificationCodeScreenState extends State<VerificationCodeScreen> {
  late List<TextEditingController> _codeControllers;
  late List<FocusNode> _focusNodes;
  bool _isLoading = false;
  String? _error;
  int _timer = 59;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _codeControllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
    _startTimer();

    if (!widget.skipCodeSending &&
        widget.type != VerificationType.passwordReset &&
        widget.type != VerificationType.googleVerification) {
      _resendCode();
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timer == 0) {
        timer.cancel();
        setState(() {});
      } else {
        setState(() {
          _timer--;
        });
      }
    });
  }

  String _getTitle() {
    switch (widget.type) {
      case VerificationType.enterAccount:
        return 'Подтверждение входа';
      case VerificationType.registration:
        return 'Подтверждение регистрации';
      case VerificationType.passwordReset:
        return 'Сброс пароля';
      case VerificationType.accountDeletion:
        return 'Подтверждение удаления';
      case VerificationType.googleVerification:
        return 'Подтверждение Google аккаунта';
    }
  }

  String _getDescription() {
    switch (widget.type) {
      case VerificationType.enterAccount:
        return 'Введите код, отправленный на ${widget.email} для входа в аккаунт';
      case VerificationType.registration:
        return 'Введите код, отправленный на ${widget.email} для завершения регистрации';
      case VerificationType.passwordReset:
        return 'Введите код, отправленный на ${widget.email} для сброса пароля';
      case VerificationType.accountDeletion:
        return 'Введите код, отправленный на ${widget.email} для подтверждения удаления аккаунта';
      case VerificationType.googleVerification:
        return 'Введите код, отправленный на ${widget.email} для подтверждения Google аккаунта';
    }
  }

  String _getButtonText() {
    switch (widget.type) {
      case VerificationType.enterAccount:
        return 'Подтвердить код';
      case VerificationType.registration:
        return 'Завершить регистрацию';
      case VerificationType.passwordReset:
        return 'Сбросить пароль';
      case VerificationType.accountDeletion:
        return 'Удалить аккаунт';
      case VerificationType.googleVerification:
        return 'Подтвердить аккаунт';
    }
  }

  String extractErrorText(Object e) {
    var text = e.toString();

    if (text.contains('Invalid verification code')) {
      return 'Неверный код подтверждения';
    }
    if (text.contains('Code expired')) {
      return 'Код истек. Отправьте новый код';
    }
    if (text.contains('Too many attempts')) {
      return 'Слишком много попыток. Попробуйте позже';
    }

    if (text.contains('"error":')) {
      final errorStart = text.indexOf('"error":') + 8;
      final errorEnd = text.indexOf('"', errorStart);
      if (errorEnd > errorStart) {
        text = text.substring(errorStart, errorEnd);
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

  void _handleCodeInput(String value, int index) {
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    } else if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    if (index == 5 && _codeControllers.every((c) => c.text.isNotEmpty)) {
      _verifyCode();
    }
  }

  Future<void> _verifyCode() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final code = _codeControllers.map((c) => c.text).join();
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _error = 'Некорректный код (6 цифр)';
        _isLoading = false;
      });
      return;
    }

    try {
      final api = ApiService();
      final codeInt = int.parse(code);

      switch (widget.type) {
        case VerificationType.registration:
          await api.verifyCode(codeInt);
          if (mounted) {
            _resendTimer?.cancel();
            if (widget.onSuccess != null) {
              widget.onSuccess!(widget.email, widget.password);
            }
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
          break;

        case VerificationType.passwordReset:
          if (mounted) {
            _resendTimer?.cancel();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ResetPasswordScreen(
                  email: widget.email,
                  code: codeInt,
                  isFromProfile: widget.onSuccess != null,
                ),
              ),
            );
          }
          break;

        case VerificationType.accountDeletion:
          await api.deleteAccountWithCode(codeInt);
          if (mounted) {
            _resendTimer?.cancel();
            if (widget.onSuccess != null) {
              widget.onSuccess!(widget.email, null);
            } else {
              context.read<AuthCubit>().signOut();
              context.read<RoleCubit>().reset();
              context.read<onb.OnboardingCubit>().reset();
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          }
          break;

        case VerificationType.enterAccount:
          await api.verifyCode(codeInt);
          if (mounted) {
            _resendTimer?.cancel();
            if (widget.onSuccess != null) {
              widget.onSuccess!(widget.email, null);
            }
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
          break;

        case VerificationType.googleVerification:
          await api.verifyCode(codeInt);
          if (mounted) {
            _resendTimer?.cancel();
            print('📱 Google verification successful, completing sign-in...');
            if (widget.onSuccess != null) {
              widget.onSuccess!(widget.email, null);
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const RoleSelectScreen(),
              ),
            );
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = extractErrorText(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ApiService();

      if (widget.type != VerificationType.googleVerification) {
        await api.sendCode(widget.email);
      }

      _startTimer();
      for (var controller in _codeControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleBackspace() {
    for (int i = 5; i >= 0; i--) {
      if (_focusNodes[i].hasFocus) {
        if (_codeControllers[i].text.isEmpty && i > 0) {
          _codeControllers[i - 1].clear();
          _focusNodes[i - 1].requestFocus();
        } else if (_codeControllers[i].text.isNotEmpty) {
          _codeControllers[i].clear();
        }
        break;
      }
    }
  }

  Widget _buildCodeTextField(int index, double digitWidth) {
    return Container(
      width: digitWidth,
      height: digitWidth,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: TextField(
        focusNode: _focusNodes[index],
        controller: _codeControllers[index],
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 1,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: digitWidth * 0.5,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey, width: 0.5),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          if (index == 5 && value.isNotEmpty) {
            _verifyCode();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final digitWidth = (screenWidth - 32 - 60) / 6;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: RawKeyboardListener(
            focusNode: FocusNode(),
            onKey: (RawKeyEvent event) {
              if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
                _handleBackspace();
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: Text(
                    _getTitle(),
                    style: AppTextStyles.h2,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: Text(
                    _getDescription(),
                    style: AppTextStyles.lead,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) => _buildCodeTextField(i, digitWidth)),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_error == null) const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 48),
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
                      : Text(
                    _getButtonText(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: _timer > 0
                      ? Text(
                    '${(_timer ~/ 60).toString().padLeft(2, '0')}:${(_timer % 60).toString().padLeft(2, '0')}',
                    style: AppTextStyles.lead,
                  )
                      : TextButton(
                    onPressed: !_isLoading ? () {
                      if (widget.type == VerificationType.googleVerification) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Внимание'),
                            content: const Text('Код для Google аккаунта уже отправлен на вашу почту. Проверьте входящие сообщения.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      } else {
                        _resendCode();
                      }
                    } : null,
                    child: Text(
                      widget.type == VerificationType.googleVerification
                          ? 'Не приходит код?'
                          : 'Отправить код снова',
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Вернуться',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}