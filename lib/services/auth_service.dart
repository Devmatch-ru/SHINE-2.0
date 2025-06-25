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
  static final AuthService instance = AuthServiceImpl();
}

class GoogleVerificationException implements Exception {
  final String email;
  final GoogleUser googleUser;

  GoogleVerificationException(this.email, this.googleUser);

  @override
  String toString() => 'Google account needs email verification: $email';
}

class AuthServiceImpl implements AuthService {
  static const _keyIdToken = 'google_id_token';
  static const _keyAccessToken = 'google_access_token';
  static const _keyEmail = 'user_email';
  static const _keyIsLoggedIn = 'is_logged_in';
  static const _keyAuthType = 'auth_type';
  static const _keyGoogleUserId = 'google_user_id';
  static const _keyGoogleUserName = 'google_user_name';
  static const _keyGoogleUserPhoto = 'google_user_photo';

  final ApiService _apiService = ApiService();

  @override
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    final user = UserModel(email: email, password: password);
    final response = await _apiService.authenticate(user);

    if (response['error'] == null) {
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
    final user = UserModel(email: email, password: password);
    final response = await _apiService.register(user);

    if (response['error'] == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEmail, email);
      await prefs.setString(_keyAuthType, 'email');
      await prefs.setBool(_keyIsLoggedIn, true);
    } else {
      throw Exception(response['error'] ?? 'Registration failed');
    }
  }

  @override
  Future<GoogleUser?> signInWithGoogle() async {
    print('🚀 Starting Google sign-in process...');

    try {
      print('📱 Getting Google user data...');
      final googleUser = await GoogleAuthService.instance.signInAndGetUser();
      if (googleUser == null) {
        print('❌ Google user is null - user cancelled or error occurred');
        return null;
      }

      print('✅ Google user obtained: ${googleUser.email}');
      print('🔑 Google ID: ${googleUser.id}');

      final tempPassword = _generateGooglePassword(googleUser.email);
      print('🔐 Generated stable password for API');

      print('🔍 Attempting authentication with existing account...');
      try {
        final user = UserModel(email: googleUser.email, password: tempPassword);
        final authResponse = await _apiService.authenticate(user);

        print('📡 Auth API response: $authResponse');

        if (authResponse['error'] == null) {
          print('✅ Authentication successful - account exists');
          await saveGoogleUserForVerification(googleUser);
          throw GoogleVerificationException(googleUser.email, googleUser);
        } else {
          final error = authResponse['error'].toString().toLowerCase();
          print('❌ Authentication failed: ${authResponse['error']}');

          if (error.contains('неверный пароль') || error.contains('wrong password')) {
            print('⚠️ User exists but used different authentication method');
            throw GoogleConflictException(googleUser.email,
                'Аккаунт с этим email уже существует. Войдите через email и пароль или используйте восстановление пароля.');
          } else if (error.contains('пользователь не найден') ||
              error.contains('user not found') ||
              error.contains('не существует') ||
              error.contains('not exist')) {
            print('📝 User not found, proceeding to registration...');
          } else {
            throw Exception('Ошибка авторизации: ${authResponse['error']}');
          }
        }
      } catch (authError) {
        if (authError is GoogleConflictException) {
          rethrow;
        }
        print('❌ Auth API call failed: $authError');
      }

      print('📝 Attempting registration of new account...');
      try {
        final user = UserModel(email: googleUser.email, password: tempPassword);
        final registerResponse = await _apiService.register(user);

        print('📡 Register API response: $registerResponse');

        if (registerResponse['error'] == null) {
          print('📧 Registration successful, verification required');
          await saveGoogleUserForVerification(googleUser);
          throw GoogleVerificationException(googleUser.email, googleUser);
        } else {
          final error = registerResponse['error'].toString().toLowerCase();
          print('❌ Registration failed: ${registerResponse['error']}');

          if (error.contains('уже существует') || error.contains('already exists')) {
            print('🔄 Account exists, might need verification');
            await saveGoogleUserForVerification(googleUser);
            throw GoogleVerificationException(googleUser.email, googleUser);
          } else {
            throw Exception('Ошибка регистрации: ${registerResponse['error']}');
          }
        }
      } catch (regError) {
        if (regError is GoogleVerificationException) {
          rethrow;
        }

        print('❌ Registration failed: $regError');

        final errorStr = regError.toString().toLowerCase();

        if (errorStr.contains('необходимо подтвердить email') ||
            errorStr.contains('verification required') ||
            errorStr.contains('verify') ||
            errorStr.contains('код') ||
            errorStr.contains('code') ||
            errorStr.contains('подтвер') ||
            errorStr.contains('confirm')) {
          print('📧 Email verification required detected');
          await saveGoogleUserForVerification(googleUser);
          throw GoogleVerificationException(googleUser.email, googleUser);
        }

        if (errorStr.contains('уже существует') ||
            errorStr.contains('already exists') ||
            errorStr.contains('duplicate') ||
            errorStr.contains('exist')) {
          print('🔄 Account exists but might need verification');
          await saveGoogleUserForVerification(googleUser);
          throw GoogleVerificationException(googleUser.email, googleUser);
        }

        print('💥 Registration failed with error: $regError');
        throw Exception('Ошибка при работе с Google аккаунтом: ${regError.toString()}');
      }

    } catch (e) {
      if (e is GoogleVerificationException) {
        print('📧 Re-throwing verification exception for: ${e.email}');
        rethrow;
      }
      if (e is GoogleConflictException) {
        print('⚠️ Re-throwing conflict exception for: ${e.email}');
        rethrow;
      }

      print('💥 Google Sign In Error: $e');
      print('🔍 Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  @override
  Future<GoogleUser?> tryAutoSignIn() async {
    final prefs = await SharedPreferences.getInstance();
    final authType = prefs.getString(_keyAuthType);

    if (authType == 'google') {
      final googleUser = await GoogleAuthService.instance.signInSilently();

      if (googleUser != null) {
        try {
          final tempPassword = _generateGooglePassword(googleUser.email);
          final user = UserModel(email: googleUser.email, password: tempPassword);
          final authResponse = await _apiService.authenticate(user);

          if (authResponse['error'] == null) {
            return googleUser;
          }
        } catch (e) {
          print('Auto sign-in validation failed: $e');
          await signOut();
        }
      } else {
        final email = prefs.getString(_keyEmail);
        final userId = prefs.getString(_keyGoogleUserId);
        final userName = prefs.getString(_keyGoogleUserName);
        final userPhoto = prefs.getString(_keyGoogleUserPhoto);

        if (email != null && userId != null) {
          try {
            final tempPassword = _generateGooglePassword(email);
            final user = UserModel(email: email, password: tempPassword);
            final authResponse = await _apiService.authenticate(user);

            if (authResponse['error'] == null) {
              return GoogleUser(
                id: userId,
                email: email,
                name: userName,
                photoUrl: userPhoto,
                idToken: prefs.getString(_keyIdToken),
                accessToken: prefs.getString(_keyAccessToken),
              );
            }
          } catch (e) {
            print('Stored account validation failed: $e');
            await signOut();
          }
        }
      }
    }

    return null;
  }

  String _generateGooglePassword(String email) {
    const salt = 'SHINE_2024_Auth!';
    final combined = '$email$salt';
    final hash = combined.hashCode.abs();

    return 'Google${hash}Auth!';
  }

  Future<void> saveGoogleUserForVerification(GoogleUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('google_pending_email', user.email);
    await prefs.setString('google_pending_id', user.id);
    await prefs.setString('google_pending_name', user.name ?? '');
    await prefs.setString('google_pending_photo', user.photoUrl ?? '');
    if (user.idToken != null) {
      await prefs.setString('google_pending_id_token', user.idToken!);
    }
    if (user.accessToken != null) {
      await prefs.setString('google_pending_access_token', user.accessToken!);
    }
  }

  Future<GoogleUser?> getGoogleUserForVerification() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('google_pending_email');
    final id = prefs.getString('google_pending_id');

    if (email != null && id != null) {
      return GoogleUser(
        id: id,
        email: email,
        name: prefs.getString('google_pending_name'),
        photoUrl: prefs.getString('google_pending_photo'),
        idToken: prefs.getString('google_pending_id_token'),
        accessToken: prefs.getString('google_pending_access_token'),
      );
    }

    return null;
  }

  Future<void> clearGoogleUserForVerification() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('google_pending_email');
    await prefs.remove('google_pending_id');
    await prefs.remove('google_pending_name');
    await prefs.remove('google_pending_photo');
    await prefs.remove('google_pending_id_token');
    await prefs.remove('google_pending_access_token');
  }

  Future<void> completeGoogleSignIn() async {
    print('🔄 Completing Google sign-in process...');
    final googleUser = await getGoogleUserForVerification();
    if (googleUser != null) {
      print('👤 Found Google user for completion: ${googleUser.email}');
      await _saveGoogleUser(googleUser);
      await clearGoogleUserForVerification();
      print('✅ Google user saved and temp data cleared');
    } else {
      print('❌ No Google user found for completion');
      throw Exception('No Google user found for completion');
    }
  }

  Future<void> _saveGoogleUser(GoogleUser user) async {
    print('💾 Saving Google user: ${user.email}');
    final prefs = await SharedPreferences.getInstance();
    if (user.idToken != null) {
      await prefs.setString(_keyIdToken, user.idToken!);
    }
    if (user.accessToken != null) {
      await prefs.setString(_keyAccessToken, user.accessToken!);
    }
    await prefs.setString(_keyEmail, user.email);
    await prefs.setString(_keyGoogleUserId, user.id);
    await prefs.setString(_keyGoogleUserName, user.name ?? '');
    await prefs.setString(_keyGoogleUserPhoto, user.photoUrl ?? '');
    await prefs.setString(_keyAuthType, 'google');
    await prefs.setBool(_keyIsLoggedIn, true);
    print('✅ Google user saved successfully');
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    final authType = prefs.getString(_keyAuthType);

    await prefs.remove(_keyIdToken);
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyAuthType);
    await prefs.remove(_keyGoogleUserId);
    await prefs.remove(_keyGoogleUserName);
    await prefs.remove(_keyGoogleUserPhoto);
    await prefs.setBool(_keyIsLoggedIn, false);

    await clearGoogleUserForVerification();

    if (authType == 'google') {
      await GoogleAuthService.instance.signOut();
    }
  }
}