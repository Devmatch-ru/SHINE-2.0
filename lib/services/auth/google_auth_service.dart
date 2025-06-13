import 'package:google_sign_in/google_sign_in.dart';

import '../../models/user_model/dart.dart';

class GoogleAuthService {
  static final GoogleAuthService instance = GoogleAuthService._();
  late final GoogleSignIn _googleSignIn;

  GoogleAuthService._() {
    _googleSignIn = GoogleSignIn(
      // Для Android и iOS этот clientId не обязателен.
      // Его нужно указывать только для Web или если вы хотите
      // привязать свой web-клиент (например, для получения idToken).
      // clientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
      scopes: <String>['email', 'profile'],
    );
  }
  Future<void> disconnect() => _googleSignIn.disconnect();
  Future<GoogleSignInAccount?> signIn() async {
    return await _googleSignIn.signIn();
  }

  Future<void> signOut() => _googleSignIn.disconnect();

  Future<GoogleUser?> signInAndGetUser() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return GoogleUser(
      id:          account.id,
      name:        account.displayName,
      email:       account.email,
      photoUrl:    account.photoUrl,
      idToken:     auth.idToken,
      accessToken: auth.accessToken,
    );
  }
}

