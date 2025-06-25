String? validateEmail(String email) {
  final emailRegExp = RegExp(r'^[\w\.-]+@[\w\.-]+\.[a-zA-Z]{2,}$');
  if (email.isEmpty) {
    return 'Email не может быть пустым';
  }
  if (!emailRegExp.hasMatch(email)) {
    return 'Некорректный email';
  }
  return null;
}

String? validatePassword(String password) {
  if (password.isEmpty) {
    return 'Пароль не может быть пустым';
  }
  if (password.length < 6) {
    return 'Пароль должен быть не менее 6 символов';
  }
  if (!RegExp(r'[A-Z]').hasMatch(password)) {
    return 'Пароль должен содержать хотя бы одну заглавную букву';
  }
  if (!RegExp(r'[0-9]').hasMatch(password)) {
    return 'Пароль должен содержать хотя бы одну цифру';
  }
  if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_]').hasMatch(password)) {
    return 'Пароль должен содержать спецсимвол';
  }

  return null;
}
