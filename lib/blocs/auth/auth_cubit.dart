import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/auth_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;
  AuthCubit(this._authService) : super(AuthLoading()) {
    _init();
  }

  Future<void> _init() async {
    final loggedIn = await _authService.isLoggedIn();
    emit(loggedIn ? Authenticated() : Unauthenticated());
  }

  Future<void> signIn(String email, String password) async {
    emit(AuthLoading());
    await _authService.signInWithEmail(email, password);
    emit(Authenticated());
  }

  Future<void> signUp(String email, String password) async {
    emit(AuthLoading());
    await _authService.signUpWithEmail(email, password);
    emit(Authenticated());
  }

  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    await _authService.signInWithGoogle();
    emit(Authenticated());
  }

  Future<void> signInWithApple() async {
    emit(AuthLoading());
    await _authService.signInWithApple();
    emit(Authenticated());
  }

  Future<void> signOut() async {
    emit(AuthLoading());
    // TODO: _authService.signOut();
    emit(Unauthenticated());
  }
}
