import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/user_model/dart.dart';

class GoogleTestScreen extends StatefulWidget {
  const GoogleTestScreen({super.key});

  @override
  State<GoogleTestScreen> createState() => _GoogleTestScreenState();
}

class _GoogleTestScreenState extends State<GoogleTestScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'profile',
      // при необходимости добавьте другие области (contacts, drive и т.д.)
    ],
  );

  GoogleUser? _user;
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        // пользователь отменил вход
        setState(() => _loading = false);
        return;
      }
      final auth = await account.authentication;
      setState(() {
        _user = GoogleUser(
          id:          account.id,
          email:       account.email,
          name:        account.displayName,
          photoUrl:    account.photoUrl,
          idToken:     auth.idToken,
          accessToken: auth.accessToken,
        );
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при входе: $e')),
      );
    }
  }

  Future<void> _signOut() async {
    await _googleSignIn.disconnect();
    setState(() {
      _user = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Sign-In Test')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _user == null
            ? ElevatedButton.icon(
          icon: Image.asset(
            'assets/images/google.png',
            width: 24,
            height: 24,
          ),
          label: const Text('Sign in with Google'),
          onPressed: _signIn,
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: _user!.photoUrl != null
                    ? NetworkImage(_user!.photoUrl!)
                    : null,
                child: _user!.photoUrl == null
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              const SizedBox(height: 12),
              Text('Name: ${_user!.name ?? '—'}'),
              Text('Email: ${_user!.email}'),
              Text('ID: ${_user!.id}'),
              const SizedBox(height: 12),
              Text(
                'ID Token:\n${_user!.idToken ?? '—'}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Access Token:\n${_user!.accessToken ?? '—'}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _signOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}