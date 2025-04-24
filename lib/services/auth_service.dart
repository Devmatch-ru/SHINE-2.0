abstract class AuthService {
  Future<bool> isLoggedIn();
  Future<void> signInWithEmail(String email, String password);
  Future<void> signUpWithEmail(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> signInWithApple();

  static final AuthService instance = _AuthServiceImpl();
}

class _AuthServiceImpl implements AuthService {
  @override
  Future<bool> isLoggedIn() async {
    return false; // TODO: check secure storage
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    // TODO: call backend
  }

  @override
  Future<void> signUpWithEmail(String email, String password) async {
    // TODO: call backend
  }

  @override
  Future<void> signInWithGoogle() async {
    // TODO: Google OAuth
  }

  @override
  Future<void> signInWithApple() async {
    // TODO: Apple OAuth
  }
}
