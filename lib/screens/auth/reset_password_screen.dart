import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../theme/app_constant.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/validators.dart';
import '../../services/api_service.dart';
import 'dart:convert';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final int code;
  final bool isFromProfile;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.code,
    required this.isFromProfile,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _passwordError;
  String? _confirmError;
  String? _codeError;
  bool _showCodeInput = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.email;
    _codeCtrl.text = widget.code.toString();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
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

  Future<void> _resetPassword() async {
    final passwordError = validatePassword(_passwordCtrl.text);
    final confirmError =
        _passwordCtrl.text != _confirmCtrl.text ? 'Пароли не совпадают' : null;
    final codeError = _showCodeInput &&
            (_codeCtrl.text.isEmpty ||
                !RegExp(r'^\d{6}$').hasMatch(_codeCtrl.text))
        ? 'Введите корректный код (6 цифр)'
        : null;

    setState(() {
      _passwordError = passwordError;
      _confirmError = confirmError;
      _codeError = codeError;
    });

    if (passwordError != null || confirmError != null || codeError != null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ApiService();
      final code = _showCodeInput ? int.parse(_codeCtrl.text) : widget.code;
      final response = await api.resetPassword(code, _passwordCtrl.text);

      if (!mounted) return;

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пароль успешно изменен')),
        );

        if (widget.isFromProfile) {
          Navigator.of(context).pop();
        } else {
          context.read<AuthCubit>().signIn(widget.email, _passwordCtrl.text);
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        final error = response['error'] ?? 'Ошибка при смене пароля';
        if (error.toLowerCase().contains('код') ||
            error.toLowerCase().contains('code')) {
          setState(() {
            _showCodeInput = true;
            _codeError = error;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      final error = extractErrorText(e);
      if (error.toLowerCase().contains('код') ||
          error.toLowerCase().contains('code')) {
        setState(() {
          _showCodeInput = true;
          _codeError = error;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        leadingWidth: 100,
        leading: TextButton.icon(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          label: Text('Назад',
              style: AppTextStyles.body.copyWith(color: AppColors.primary)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Смена пароля', style: AppTextStyles.lead),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              CustomTextField(
                label: 'EMAIL',
                hint: 'Ваш Email',
                controller: _emailCtrl,
                enabled: false,
                backgroundColor: Colors.white,
              ),
              if (_showCodeInput) ...[
                const SizedBox(height: AppSpacing.m),
                CustomTextField(
                  label: 'КОД ПОДТВЕРЖДЕНИЯ',
                  hint: 'Введите код из письма',
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  errorText: _codeError,
                  backgroundColor: Colors.white,
                ),
              ],
              const SizedBox(height: AppSpacing.m),
              CustomTextField(
                label: 'ВВЕДИТЕ ПАРОЛЬ',
                hint: 'Введите пароль',
                controller: _passwordCtrl,
                obscure: true,
                errorText: _passwordError,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: AppSpacing.m),
              CustomTextField(
                label: 'ПОВТОРИТЕ ПАРОЛЬ',
                hint: 'Повторите пароль',
                controller: _confirmCtrl,
                obscure: true,
                errorText: _confirmError,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
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
                    : const Text(
                        'Сменить пароль',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
