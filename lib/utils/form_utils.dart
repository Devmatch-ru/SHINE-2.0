// lib/utils/form_utils.dart
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class FormUtils {
  static final Map<String, DateTime> _lastSubmissions = {};

  static bool canSubmitForm(String formId, {Duration cooldown = const Duration(seconds: 2)}) {
    final now = DateTime.now();
    final lastSubmission = _lastSubmissions[formId];

    if (lastSubmission == null || now.difference(lastSubmission) > cooldown) {
      _lastSubmissions[formId] = now;
      return true;
    }

    return false;
  }

  static void clearSubmissionCache() {
    _lastSubmissions.clear();
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email не может быть пустым';
    }

    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Введите корректный email';
    }

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Пароль не может быть пустым';
    }

    if (value.length < 6) {
      return 'Пароль должен содержать минимум 6 символов';
    }

    return null;
  }

  static String? validatePasswordConfirmation(String? value, String? originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Подтвердите пароль';
    }

    if (value != originalPassword) {
      return 'Пароли не совпадают';
    }

    return null;
  }

  static String? validateVerificationCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите код';
    }

    if (value.length != 6) {
      return 'Код должен содержать 6 цифр';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'Код должен содержать только цифры';
    }

    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Имя не может быть пустым';
    }

    if (value.trim().length < 2) {
      return 'Имя должно содержать минимум 2 символа';
    }

    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Номер телефона не может быть пустым';
    }

    final phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');
    if (!phoneRegex.hasMatch(value.replaceAll(RegExp(r'[\s\-\(\)]'), ''))) {
      return 'Введите корректный номер телефона';
    }

    return null;
  }
}

class AppTextInputFormatters {
  static final emailFormatter = FilteringTextInputFormatter.deny(RegExp(r'\s'));

  static final digitsOnlyFormatter = FilteringTextInputFormatter.digitsOnly;

  static final verificationCodeFormatter = LengthLimitingTextInputFormatter(6);

  static final nameFormatter = FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Zа-яА-Я\s]'));

  static final phoneFormatter = FilteringTextInputFormatter.allow(RegExp(r'[\d\+\-\(\)\s]'));

  static TextInputFormatter lengthLimiter(int maxLength) {
    return LengthLimitingTextInputFormatter(maxLength);
  }

  static TextInputFormatter regexFormatter(String pattern) {
    return FilteringTextInputFormatter.allow(RegExp(pattern));
  }
}

mixin FormStateMixin<T extends StatefulWidget> on State<T> {
  final Map<String, String?> _errors = {};
  final Map<String, bool> _fieldTouched = {};
  bool _isSubmitting = false;

  String? getFieldError(String fieldName) => _errors[fieldName];

  void setFieldError(String fieldName, String? error) {
    setState(() {
      _errors[fieldName] = error;
    });
  }

  void clearErrors() {
    setState(() {
      _errors.clear();
      _fieldTouched.clear();
    });
  }

  bool isFieldTouched(String fieldName) => _fieldTouched[fieldName] ?? false;

  void markFieldAsTouched(String fieldName) {
    setState(() {
      _fieldTouched[fieldName] = true;
    });
  }

  bool get hasErrors => _errors.values.any((error) => error != null);

  bool get isSubmitting => _isSubmitting;

  void setSubmitting(bool submitting) {
    setState(() {
      _isSubmitting = submitting;
    });
  }

  void validateField(String fieldName, String? value, String? Function(String?) validator) {
    final error = validator(value);
    setFieldError(fieldName, error);
  }

  bool validateForm(Map<String, String?> values, Map<String, String? Function(String?)> validators) {
    clearErrors();

    for (final entry in validators.entries) {
      final fieldName = entry.key;
      final validator = entry.value;
      final value = values[fieldName];

      validateField(fieldName, value, validator);
    }

    return !hasErrors;
  }
}

class MultiFieldController {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  TextEditingController getController(String fieldName) {
    return _controllers.putIfAbsent(fieldName, () => TextEditingController());
  }

  FocusNode getFocusNode(String fieldName) {
    return _focusNodes.putIfAbsent(fieldName, () => FocusNode());
  }

  String getValue(String fieldName) {
    return getController(fieldName).text;
  }

  void setValue(String fieldName, String value) {
    getController(fieldName).text = value;
  }

  void clearAll() {
    for (final controller in _controllers.values) {
      controller.clear();
    }
  }

  void clearField(String fieldName) {
    getController(fieldName).clear();
  }

  void focusNext(String currentField, String nextField) {
    getFocusNode(currentField).unfocus();
    getFocusNode(nextField).requestFocus();
  }

  Map<String, String> getAllValues() {
    return _controllers.map((key, controller) => MapEntry(key, controller.text));
  }

  void addListener(String fieldName, VoidCallback listener) {
    getController(fieldName).addListener(listener);
  }

  void removeListener(String fieldName, VoidCallback listener) {
    getController(fieldName).removeListener(listener);
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    _controllers.clear();
    _focusNodes.clear();
  }
}

class FormKeyboardUtils {
  static void setupAutoHideKeyboard(List<FocusNode> focusNodes) {
    for (final focusNode in focusNodes) {
      focusNode.addListener(() {
        if (!focusNode.hasFocus) {
          // Небольшая задержка для корректной работы
          Future.delayed(const Duration(milliseconds: 100), () {
            SystemChannels.textInput.invokeMethod('TextInput.hide');
          });
        }
      });
    }
  }

  static void setupFieldNavigation(Map<String, FocusNode> focusNodes) {
    final keys = focusNodes.keys.toList();

    for (int i = 0; i < keys.length; i++) {
      final currentKey = keys[i];
      final nextKey = i < keys.length - 1 ? keys[i + 1] : null;

      focusNodes[currentKey]?.addListener(() {
        if (focusNodes[currentKey]!.hasFocus && nextKey != null) {
          // Можно добавить логику для автоматического перехода
        }
      });
    }
  }

  static void hideKeyboard() {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  static void showKeyboard() {
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }
}