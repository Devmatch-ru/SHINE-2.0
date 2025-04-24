import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/role/role_cubit.dart';

class RoleSelect extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Выберите роль')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ElevatedButton(
            onPressed: () => context.read<RoleCubit>().selectHost(),
            child: Text('Я фотографирую'),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.read<RoleCubit>().selectClient(),
            child: Text('Меня фотографируют'),
          ),
        ]),
      ),
    );
  }
}
