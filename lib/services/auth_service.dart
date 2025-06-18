import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model/dart.dart';
import 'auth/google_auth_service.dart';

abstract class AuthService {
  Future<bool> isLoggedIn();
  Future<void> signInWithEmail(String email, String password);
  Future<void> signUpWithEmail(String email, String password);
  Future<GoogleUser?> signInWithGoogle();
  Future<void> signOut();
  static final AuthService instance = _AuthServiceImpl();
}

class _AuthServiceImpl implements AuthService {
  static const _keyIdToken = 'google_id_token';
  static const _keyAccessToken = 'google_access_token';
  static const _keyEmail = 'user_email';
  static const _keyIsLoggedIn = 'is_logged_in';

  @override
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    // TODO
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  @override
  Future<void> signUpWithEmail(String email, String password) async {
    // TODO
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  @override
  Future<GoogleUser?> signInWithGoogle() async {
    await GoogleAuthService.instance.signOut();
    final user = await GoogleAuthService.instance.signInAndGetUser();
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      if (user.idToken != null) {
        await prefs.setString(_keyIdToken, user.idToken!);
      }
      if (user.accessToken != null) {
        await prefs.setString(_keyAccessToken, user.accessToken!);
      }
      await prefs.setString(_keyEmail, user.email);
      await prefs.setBool(_keyIsLoggedIn, true);
    }
    return user;
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIdToken);
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyIsLoggedIn);

    await GoogleAuthService.instance.signOut();
    await GoogleAuthService.instance.disconnect();
  }
}
