// lib/blocs/auth/auth_cubit.dart
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
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString(_keyEmail) ?? '';
        emit(Authenticated(
          id: email,
          email: email,
          name: null,
          photoUrl: null,
        ));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signIn(String email, String password) async {
    emit(AuthLoading());
    try {
      await _authService.signInWithEmail(email, password);
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
        emit(Authenticated(
          id: googleUser.id,
          email: googleUser.email,
          name: googleUser.name,
          photoUrl: googleUser.photoUrl,
        ));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signOut() async {
    emit(AuthLoading());
    try {
      await _authService.signOut();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
