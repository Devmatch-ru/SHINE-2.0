import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/auth/auth_state.dart';
import '../../theme/app_constant.dart';
import '../../widgets/custom_text_field.dart';
import '../auth/verification_code_screen.dart';
import '../../blocs/onboarding/onboarding_cubit.dart' as onb;
import '../../blocs/role/role_cubit.dart';

class ProfileAction {
  final String title;
  final VoidCallback onTap;
  final Color? textColor;

  ProfileAction({
    required this.title,
    required this.onTap,
    this.textColor,
  });
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _emailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _loadUserEmail() {
    final state = context.read<AuthCubit>().state;
    if (state is Authenticated) {
      _emailCtrl.text = state.email;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: _buildAppBar(),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: AppSpacing.l),
          _AnimatedSection(
            delay: 0,
            child: _EmailSection(controller: _emailCtrl),
          ),
          _AnimatedSection(
            delay: 200,
            child: _ActionsSection(
              actions: _getProfileActions(),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.bgMain,
      elevation: 0,
      automaticallyImplyLeading: false,
      leadingWidth: 130,
      leading: TextButton.icon(
        icon: const Icon(Icons.arrow_back, color: AppColors.primary),
        label: Text(
          'Назад',
          style: AppTextStyles.body.copyWith(color: AppColors.primary),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text('Мой профиль', style: AppTextStyles.lead),
      centerTitle: true,
    );
  }

  List<ProfileAction> _getProfileActions() => [
    ProfileAction(
      title: 'Сбросить пароль',
      onTap: _resetPassword,
    ),
    ProfileAction(
      title: 'Удалить аккаунт',
      onTap: _showDeleteDialog,
      textColor: AppColors.error,
    ),
    ProfileAction(
      title: 'Выйти из аккаунта',
      onTap: _signOut,
    ),
  ];

  void _resetPassword() {
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerificationCodeScreen(
          email: _emailCtrl.text,
          type: VerificationType.passwordReset,
        ),
      ),
    );
  }

  void _signOut() {
    context.read<AuthCubit>().signOut();
    context.read<RoleCubit>().reset();
    context.read<onb.OnboardingCubit>().reset();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _DeleteAccountDialog(
        onConfirm: () => _deleteAccount(ctx),
      ),
    );
  }

  void _deleteAccount(BuildContext dialogContext) {
    Navigator.of(dialogContext).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerificationCodeScreen(
          email: _emailCtrl.text,
          type: VerificationType.accountDeletion,
          onSuccess: (_, __) {
            context.read<AuthCubit>().signOut();
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
    );
  }
}

class _AnimatedSection extends StatefulWidget {
  final int delay;
  final Widget child;

  const _AnimatedSection({
    required this.delay,
    required this.child,
  });

  @override
  State<_AnimatedSection> createState() => _AnimatedSectionState();
}

class _AnimatedSectionState extends State<_AnimatedSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _slideY;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    );
    _slideY = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _slideY.value),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _EmailSection extends StatelessWidget {
  final TextEditingController controller;

  const _EmailSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
            child: Text('Данные для входа', style: AppTextStyles.lead),
          ),
          const SizedBox(height: AppSpacing.m),
          CustomTextField(
            label: 'EMAIL',
            hint: 'Ваш Email',
            controller: controller,
            enabled: false,
          ),
        ],
      ),
    );
  }
}

class _ActionsSection extends StatelessWidget {
  final List<ProfileAction> actions;

  const _ActionsSection({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      child: Column(
        children: actions
            .asMap()
            .entries
            .map((entry) => _AnimatedActionTile(
          delay: entry.key * 100,
          action: entry.value,
        ))
            .toList(),
      ),
    );
  }
}

class _AnimatedActionTile extends StatefulWidget {
  final int delay;
  final ProfileAction action;

  const _AnimatedActionTile({
    required this.delay,
    required this.action,
  });

  @override
  State<_AnimatedActionTile> createState() => _AnimatedActionTileState();
}

class _AnimatedActionTileState extends State<_AnimatedActionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _slideX;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    );
    _slideX = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );

    Future.delayed(Duration(milliseconds: 300 + widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(_slideX.value, 0),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              minVerticalPadding: 0,
              title: Text(
                widget.action.title,
                style: widget.action.textColor != null
                    ? AppTextStyles.body.copyWith(color: widget.action.textColor)
                    : AppTextStyles.body,
              ),
              onTap: widget.action.onTap,
            ),
          ),
        );
      },
    );
  }
}

class _DeleteAccountDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const _DeleteAccountDialog({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Center(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Удалить аккаунт?', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Отменить действие будет невозможно',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.l),
            _DialogButton(
              text: 'Нет, отменить',
              backgroundColor: AppColors.primary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: AppSpacing.s),
            _DialogButton(
              text: 'Да, удалить',
              backgroundColor: AppColors.error,
              onPressed: onConfirm,
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final VoidCallback onPressed;

  const _DialogButton({
    required this.text,
    required this.backgroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: AppColors.primaryLight,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        ),
        child: Text(
          text,
          style: AppTextStyles.lead.copyWith(color: AppColors.primaryLight),
        ),
      ),
    );
  }
}