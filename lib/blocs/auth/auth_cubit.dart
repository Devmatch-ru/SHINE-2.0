import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;
  static const _keyEmail = 'user_email';

  AuthCubit(this._authService) : super(AuthLoading()) {
    _init();
  }

  Future<void> _init() async {
    emit(AuthLoading());
    try {
      final loggedIn = await _authService.isLoggedIn();
      if (loggedIn) {
        // Сначала пробуем автоматический вход через Google
        final googleUser = await _authService.tryAutoSignIn();

        if (googleUser != null) {
          emit(Authenticated(
            id: googleUser.id,
            email: googleUser.email,
            name: googleUser.name,
            photoUrl: googleUser.photoUrl,
          ));
        } else {
          // Если Google вход не удался, используем сохраненный email
          final prefs = await SharedPreferences.getInstance();
          final email = prefs.getString(_keyEmail) ?? '';
          if (email.isNotEmpty) {
            emit(Authenticated(
              id: email,
              email: email,
              name: null,
              photoUrl: null,
            ));
          } else {
            emit(Unauthenticated());
          }
        }
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      print('Auth Init Error: $e');
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signIn(String email, String password) async {
    emit(AuthLoading());
    try {
      await _authService.signInWithEmail(email, password);

      // Сохраняем email в SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEmail, email);

      emit(Authenticated(
        id: email,
        email: email,
        name: null,
        photoUrl: null,
      ));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signUp(String email, String password) async {
    emit(AuthLoading());
    try {
      await _authService.signUpWithEmail(email, password);

      // Сохраняем email в SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEmail, email);

      emit(Authenticated(
        id: email,
        email: email,
        name: null,
        photoUrl: null,
      ));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      final googleUser = await _authService.signInWithGoogle();
      if (googleUser == null) {
        emit(Unauthenticated());
      } else {
        // Сохраняем email в SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyEmail, googleUser.email);

        emit(Authenticated(
          id: googleUser.id,
          email: googleUser.email,
          name: googleUser.name,
          photoUrl: googleUser.photoUrl,
        ));
      }
    } catch (e) {
      print('Google Sign In Error: $e');

      // Проверяем, нужна ли верификация email
      final errorStr = e.toString();
      if (errorStr.contains('необходимо подтвердить email') ||
          errorStr.contains('verification required') ||
          errorStr.contains('code sent')) {

        // Если нужна верификация, emit специальное состояние
        emit(AuthError('google_verification_required'));
      } else {
        emit(AuthError(e.toString()));
      }
    }
  }

  Future<void> signOut() async {
    emit(AuthLoading());
    try {
      await _authService.signOut();

      // Очищаем email из SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyEmail);

      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> refresh() async {
    await _init();
  }
}