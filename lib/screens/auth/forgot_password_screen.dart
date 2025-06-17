import 'package:flutter/material.dart';
import '../../theme/main_design.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/validators.dart';
import '../../services/api_service.dart';
import 'dart:convert';
import 'verification_code_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  String extractErrorText(Object e) {
    var text = e.toString();

    // Извлекаем сообщение об ошибке из JSON ответа
    if (text.contains('"error":')) {
      final errorStart = text.indexOf('"error":') + 8;
      final errorEnd = text.indexOf('"', errorStart);
      if (errorEnd > errorStart) {
        return text.substring(errorStart, errorEnd);
      }
    }

    // Убираем технические детали
    text = text
        .replaceAll('Exception: ', '')
        .replaceAll('Network error: ', '')
        .replaceAll('Request failed with status: ', '');

    // Если это ответ сервера с ошибкой, извлекаем только сообщение
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

  Future<void> _sendCode() async {
    final emailError = validateEmail(_emailController.text.trim());
    if (emailError != null) {
      setState(() => _error = emailError);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ApiService();
      final response = await api.sendCode(_emailController.text.trim());

      if (mounted) {
        if (response['success'] == true) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VerificationCodeScreen(
                email: _emailController.text.trim(),
                type: VerificationType.passwordReset,
                skipCodeSending: true,
              ),
            ),
          );
        } else {
          setState(() => _error = response['error'] ?? 'Неизвестная ошибка');
        }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        leadingWidth: 100,
        leading: TextButton.icon(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          label: Text('Назад',
              style: AppTextStyles.body.copyWith(color: AppColors.primary)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Забыли пароль?', style: AppTextStyles.lead),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Text(
                  'Введите email и мы пришлём письмо для сброса пароля',
                  style: AppTextStyles.lead,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              CustomTextField(
                label: 'ВВЕДИТЕ EMAIL',
                hint: 'Ваш Email',
                controller: _emailController,
                errorText: _error,
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendCode,
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
                        'Продолжить',
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
