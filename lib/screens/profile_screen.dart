// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_cubit.dart';
import '../blocs/auth/auth_state.dart';
import '../theme/main_design.dart';
import '../widgets/custom_text_field.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _emailCtrl   = TextEditingController();
  final _passwordCtrl= TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showConfirm  = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AuthCubit>().state;
    if (state is Authenticated) {
      _emailCtrl.text = state.email;
    }
    _passwordCtrl.addListener(() {
      setState(() {
        _showConfirm = _passwordCtrl.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        leading: const BackButton(color: AppColors.primary),
        title: const Text('Мой профиль', style: AppTextStyles.lead),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: AppSpacing.l),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                  child: Text(
                    'Данные для входа',
                    style: AppTextStyles.lead,
                  ),
                ),

                const SizedBox(height: AppSpacing.m),

                CustomTextField(
                  label: 'ВВЕДИТЕ EMAIL',
                  hint: 'Ваш Email',
                  controller: _emailCtrl,
                ),
                const SizedBox(height: AppSpacing.s),

                CustomTextField(
                  label: 'ВВЕДИТЕ ПАРОЛЬ',
                  hint: 'Введите пароль',
                  controller: _passwordCtrl,
                  obscure: true,
                ),
                if (_showConfirm) ...[
                  const SizedBox(height: AppSpacing.s),
                  CustomTextField(
                    label: 'ПОВТОРИТЕ ПАРОЛЬ',
                    hint: 'Повторите пароль',
                    controller: _confirmCtrl,
                    obscure: true,

                  ),
                ],

                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(
                    'Удалить аккаунт',
                    style: AppTextStyles.body.copyWith(color: AppColors.error),
                  ),
                  onTap: _showDeleteDialog,
                ),
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: const Text('Выйти из аккаунта', style: AppTextStyles.body),
                  onTap: () => context.read<AuthCubit>().signOut(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(AppSpacing.s),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: AppBorderRadius.m,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Удалить аккаунт?',
                style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.s),
            Text('Отменить действие будет невозможно',
                style: AppTextStyles.body, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.l),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryLight,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                ),
                child: Text(
                  'Нет, отменить',
                  style: AppTextStyles.lead.copyWith(color: AppColors.primaryLight),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.read<AuthCubit>().signOut();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.primaryLight,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                ),
                child: Text(
                  'Да, удалить',
                  style: AppTextStyles.lead.copyWith(color: AppColors.primaryLight),
                ),

              ),
            ),
          ]),
        ),
      ),
    );
  }
}
