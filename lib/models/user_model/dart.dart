
class GoogleUser {
    final String id;
    final String email;
    final String? name;
    final String? photoUrl;
    final String? idToken;
    final String? accessToken;

    GoogleUser({
        required this.id,
                required this.email,
                this.name,
                this.photoUrl,
                this.idToken,
                this.accessToken,
    });
}