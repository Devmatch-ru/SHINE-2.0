import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth/google_auth_service.dart';
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
        final googleUser = await _authService.tryAutoSignIn();

        if (googleUser != null) {
          emit(Authenticated(
            id: googleUser.id,
            email: googleUser.email,
            name: googleUser.name,
            photoUrl: googleUser.photoUrl,
          ));
        } else {
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
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signIn(String email, String password) async {
    emit(AuthLoading());
    try {
      await _authService.signInWithEmail(email, password);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEmail, email);

      emit(Authenticated(
        id: email,
        email: email,
        name: null,
        photoUrl: null,
      ));
    } catch (e) {
      final errorStr = e.toString();

      if (errorStr.contains('необходимо подтвердить email') ||
          errorStr.contains('verification required') ||
          errorStr.contains('verify') ||
          errorStr.contains('код') ||
          errorStr.contains('code') ||
          errorStr.contains('подтвер') ||
          errorStr.contains('confirm')) {
        emit(AuthError('email_verification_required:$email'));
      } else {
        emit(AuthError(e.toString()));
      }
    }
  }

  Future<void> signUp(String email, String password) async {
    emit(AuthLoading());
    try {
      await _authService.signUpWithEmail(email, password);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEmail, email);

      emit(Authenticated(
        id: email,
        email: email,
        name: null,
        photoUrl: null,
      ));
    } catch (e) {
      final errorStr = e.toString();

      if (errorStr.contains('необходимо подтвердить email') ||
          errorStr.contains('verification required') ||
          errorStr.contains('verify') ||
          errorStr.contains('код') ||
          errorStr.contains('code') ||
          errorStr.contains('подтвер') ||
          errorStr.contains('confirm')) {
        emit(AuthError('email_verification_required:$email'));
      } else {
        emit(AuthError(e.toString()));
      }
    }
  }

  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      final googleUser = await _authService.signInWithGoogle();
      if (googleUser == null) {
        emit(Unauthenticated());
      } else {
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

      if (e is GoogleVerificationException) {
        await (AuthService.instance as AuthServiceImpl).saveGoogleUserForVerification(e.googleUser);
        emit(AuthError('google_verification_required:${e.email}'));
      } else if (e is GoogleConflictException) {
        emit(AuthError('google_conflict:${e.email}:${e.message}'));
      } else {
        final errorStr = e.toString();
        if (errorStr.contains('Google account needs email verification')) {
          final emailMatch = RegExp(r'verification: (.+)').firstMatch(errorStr);
          final email = emailMatch?.group(1) ?? '';
          emit(AuthError('google_verification_required:$email'));
        } else {
          emit(AuthError(e.toString()));
        }
      }
    }
  }

  Future<void> completeGoogleSignIn() async {
    emit(AuthLoading());
    try {
      await (AuthService.instance as AuthServiceImpl).completeGoogleSignIn();

      final googleUser = await _authService.tryAutoSignIn();

      if (googleUser != null) {

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyEmail, googleUser.email);

        final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
        if (!onboardingCompleted) {
          await prefs.setBool('onboarding_completed', true);
        }

        emit(Authenticated(
          id: googleUser.id,
          email: googleUser.email,
          name: googleUser.name,
          photoUrl: googleUser.photoUrl,
        ));

      } else {
        emit(AuthError('Failed to complete Google sign in'));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signOut() async {
    emit(AuthLoading());
    try {
      await _authService.signOut();

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