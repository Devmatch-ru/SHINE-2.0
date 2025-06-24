import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model/dart.dart';
import '../models/user_model/user_model.dart';
import '../services/api_service.dart';
import 'auth/google_auth_service.dart';

abstract class AuthService {
  Future<bool> isLoggedIn();
  Future<void> signInWithEmail(String email, String password);
  Future<void> signUpWithEmail(String email, String password);
  Future<GoogleUser?> signInWithGoogle();
  Future<GoogleUser?> tryAutoSignIn();
  Future<void> signOut();
  static final AuthService instance = _AuthServiceImpl();
}

class _AuthServiceImpl implements AuthService {
  static const _keyIdToken = 'google_id_token';
  static const _keyAccessToken = 'google_access_token';
  static const _keyEmail = 'user_email';
  static const _keyIsLoggedIn = 'is_logged_in';
  static const _keyAuthType = 'auth_type'; // email или google

  final ApiService _apiService = ApiService();

  @override
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    // Используем существующий API для авторизации
    final user = UserModel(email: email, password: password);
    final response = await _apiService.authenticate(user);

    if (response['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEmail, email);
      await prefs.setString(_keyAuthType, 'email');
      await prefs.setBool(_keyIsLoggedIn, true);
    } else {
      throw Exception(response['error'] ?? 'Authentication failed');
    }
  }

  @override
  Future<void> signUpWithEmail(String email, String password) async {
    // Используем существующий API для регистрации
    final user = UserModel(email: email, password: password);
    await _apiService.register(user);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyAuthType, 'email');
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  @override
  Future<GoogleUser?> signInWithGoogle() async {
    try {
      // Получаем данные пользователя из Google
      final googleUser = await GoogleAuthService.instance.signInAndGetUser();
      if (googleUser == null) return null;

      // Генерируем временный пароль для Google пользователей
      final tempPassword = _generateGooglePassword(googleUser.id);

      // Сначала пытаемся войти (если аккаунт уже существует)
      try {
        final user = UserModel(email: googleUser.email, password: tempPassword);
        final authResponse = await _apiService.authenticate(user);

        if (authResponse['success'] == true) {
          // Аккаунт существует, успешно вошли
          await _saveGoogleUser(googleUser);
          return googleUser;
        }
      } catch (e) {
        // Если вход не удался, пытаемся зарегистрировать
        print('Auth failed, trying to register: $e');
      }

      // Пытаемся зарегистрировать новый аккаунт
      try {
        final user = UserModel(email: googleUser.email, password: tempPassword);
        await _apiService.register(user);

        // Регистрация успешна
        await _saveGoogleUser(googleUser);
        return googleUser;

      } catch (e) {
        print('Registration failed: $e');

        // Если ошибка содержит информацию о необходимости подтверждения
        final errorStr = e.toString();
        if (errorStr.contains('необходимо подтвердить email') ||
            errorStr.contains('verification required') ||
            errorStr.contains('code sent')) {

          // Сохраняем пользователя как неподтвержденного
          await _saveGoogleUser(googleUser);
          return googleUser;
        }

        // Если это другая ошибка, пробуем войти еще раз
        // (возможно, аккаунт уже был создан между попытками)
        try {
          final user = UserModel(email: googleUser.email, password: tempPassword);
          final authResponse = await _apiService.authenticate(user);

          if (authResponse['success'] == true) {
            await _saveGoogleUser(googleUser);
            return googleUser;
          }
        } catch (finalError) {
          print('Final auth attempt failed: $finalError');
        }

        throw Exception('Failed to register or authenticate with Google account');
      }

    } catch (e) {
      print('Google Sign In Error: $e');
      return null;
    }
  }

  @override
  Future<GoogleUser?> tryAutoSignIn() async {
    final prefs = await SharedPreferences.getInstance();
    final authType = prefs.getString(_keyAuthType);

    if (authType == 'google') {
      // Попытка автоматического входа через Google
      final googleUser = await GoogleAuthService.instance.signInSilently();

      if (googleUser != null) {
        // Проверяем, что аккаунт все еще действителен на сервере
        try {
          final tempPassword = _generateGooglePassword(googleUser.id);
          final user = UserModel(email: googleUser.email, password: tempPassword);
          final authResponse = await _apiService.authenticate(user);

          if (authResponse['success'] == true) {
            return googleUser;
          }
        } catch (e) {
          print('Auto sign-in validation failed: $e');
          // Если проверка не удалась, очищаем данные
          await signOut();
        }
      }
    }

    return null;
  }

  /// Генерирует стабильный пароль на основе Google ID
  String _generateGooglePassword(String googleId) {
    // Создаем стабильный пароль на основе Google ID
    // Используем префикс для идентификации Google аккаунтов
    return 'google_${googleId.hashCode.abs()}';
  }

  Future<void> _saveGoogleUser(GoogleUser user) async {
    final prefs = await SharedPreferences.getInstance();
    if (user.idToken != null) {
      await prefs.setString(_keyIdToken, user.idToken!);
    }
    if (user.accessToken != null) {
      await prefs.setString(_keyAccessToken, user.accessToken!);
    }
    await prefs.setString(_keyEmail, user.email);
    await prefs.setString(_keyAuthType, 'google');
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    final authType = prefs.getString(_keyAuthType);

    // Очищаем все данные
    await prefs.remove(_keyIdToken);
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyAuthType);
    await prefs.setBool(_keyIsLoggedIn, false);

    // Если был Google аккаунт, выходим из Google
    if (authType == 'google') {
      await GoogleAuthService.instance.signOut();
    }
  }
}