// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_cubit.dart';
import '../blocs/auth/auth_state.dart';
import '../theme/main_design.dart';
import '../widgets/custom_text_field.dart';
import 'auth/verification_code_screen.dart';
import '../services/api_service.dart';
import '../blocs/onboarding/onboarding_cubit.dart' as onb;
import '../blocs/role/role_cubit.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _emailCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = context.read<AuthCubit>().state;
    if (state is Authenticated) {
      _emailCtrl.text = state.email;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
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
            Text('Удалить аккаунт?', style: AppTextStyles.h2),
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
                  style: AppTextStyles.lead
                      .copyWith(color: AppColors.primaryLight),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VerificationCodeScreen(
                        email: _emailCtrl.text,
                        type: VerificationType.accountDeletion,
                        onSuccess: (_, __) {
                          context.read<AuthCubit>().signOut();
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.primaryLight,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                ),
                child: Text(
                  'Да, удалить',
                  style: AppTextStyles.lead
                      .copyWith(color: AppColors.primaryLight),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _resetPassword() async {
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerificationCodeScreen(
            email: _emailCtrl.text,
            type: VerificationType.passwordReset,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        automaticallyImplyLeading: false,
        leadingWidth: 130,
        leading: TextButton.icon(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          label: Text('Назад',
              style: AppTextStyles.body.copyWith(color: AppColors.primary)),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                  child: Text(
                    'Данные для входа',
                    style: AppTextStyles.lead,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                CustomTextField(
                  label: 'EMAIL',
                  hint: 'Ваш Email',
                  controller: _emailCtrl,
                  enabled: false,
                ),
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  minVerticalPadding: 0,
                  title:
                      const Text('Сбросить пароль', style: AppTextStyles.body),
                  onTap: _resetPassword,
                ),
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  minVerticalPadding: 0,
                  title: Text(
                    'Удалить аккаунт',
                    style: AppTextStyles.body.copyWith(color: AppColors.error),
                  ),
                  onTap: _showDeleteDialog,
                ),
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  minVerticalPadding: 0,
                  title: const Text('Выйти из аккаунта',
                      style: AppTextStyles.body),
                  onTap: () {
                    context.read<AuthCubit>().signOut();
                    context.read<RoleCubit>().reset();
                    context.read<onb.OnboardingCubit>().reset();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
