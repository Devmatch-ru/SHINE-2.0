import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_cubit.dart';
import '../blocs/auth/auth_state.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Вход / Регистрация')),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Пароль'),
                obscureText: true,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.read<AuthCubit>().signIn(
                  _emailController.text,
                  _passwordController.text,
                ),
                child: Text('Войти'),
              ),
              TextButton(
                onPressed: () => context.read<AuthCubit>().signUp(
                  _emailController.text,
                  _passwordController.text,
                ),
                child: Text('Зарегистрироваться'),
              ),
              Divider(),
              ElevatedButton(
                onPressed: () => context.read<AuthCubit>().signInWithGoogle(),
                child: Text('Google'),
              ),
              ElevatedButton(
                onPressed: () => context.read<AuthCubit>().signInWithApple(),
                child: Text('Apple'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
