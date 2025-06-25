import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import '../../config/api_config.dart';
import '../../models/user_model/dart.dart';

class GoogleAuthService {
  static final GoogleAuthService instance = GoogleAuthService._();
  late final GoogleSignIn _googleSignIn;

  GoogleAuthService._() {
    _googleSignIn = GoogleSignIn(
      clientId: _getClientId(),
      scopes: <String>[
        'email',
        'profile',
      ],
    );
  }

  String? _getClientId() {
    return Platform.isIOS
        ? GoogleConfig.clientId
        : null;
  }

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      await _googleSignIn.signOut();

      return await _googleSignIn.signIn();
    } catch (error) {
      print('Google Sign In Error: $error');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  Future<void> disconnect() async {
    await _googleSignIn.disconnect();
  }

  Future<GoogleUser?> signInAndGetUser() async {
    try {
      final account = await signIn();
      if (account == null) return null;

      final auth = await account.authentication;

      return GoogleUser(
        id: account.id,
        name: account.displayName,
        email: account.email,
        photoUrl: account.photoUrl,
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );
    } catch (error) {
      print('Google Sign In Error: $error');
      return null;
    }
  }

  Future<GoogleUser?> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return null;

      final auth = await account.authentication;

      return GoogleUser(
        id: account.id,
        name: account.displayName,
        email: account.email,
        photoUrl: account.photoUrl,
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );
    } catch (error) {
      print('Silent Sign In Error: $error');
      return null;
    }
  }
}

class GoogleConflictException implements Exception {
  final String email;
  final String message;

  GoogleConflictException(this.email, this.message);

  @override
  String toString() => 'Google account conflict for $email: $message';
}