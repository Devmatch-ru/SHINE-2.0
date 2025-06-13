abstract class AuthState {}
class AuthLoading extends AuthState {}
class Authenticated extends AuthState {
  final String id;
  final String email;
  final String? name;
  final String? photoUrl;

  Authenticated({
    required this.id,
    required this.email,
    this.name,
    this.photoUrl,
  });
}
class Unauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;

  AuthError(this.message);
}
