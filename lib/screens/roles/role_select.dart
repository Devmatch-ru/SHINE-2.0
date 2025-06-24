// lib/screens/roles/improved_role_select_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/role/role_cubit.dart';
import '../../blocs/wifi/wifi_cubit.dart';
import '../../blocs/wifi/wifi_state.dart';
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';
import '../../theme/dimensions.dart';
import '../../theme/animations.dart';
import '../../theme/icons.dart';
import '../../widgets/common/slide_transition_page.dart';
import '../../screens/profile_screen.dart';
import '../roles/ReceiverScreen.dart';
import '../settings/settings_screen.dart';
import '../tip_screen/client_tip_screen.dart';
import '../tip_screen/host_tip_screen.dart';
import '../roles/host_selection_screen.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _slideController = AnimationController(
      duration: AppAnimations.slow,
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: AppAnimations.normal,
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: AppAnimations.verySlow,
      vsync: this,
    );

    // Запуск анимаций появления
    _slideController.forward();
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: Column(
          children: [
            SlideTransition(
              position: AppAnimations.slideInFromLeft(_slideController),
              child: FadeTransition(
                opacity: _fadeController,
                child: const _TopBar(),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SlideTransition(
              position: AppAnimations.slideInFromRight(_slideController),
              child: FadeTransition(
                opacity: _fadeController,
                child: const _InspirationBanner(),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: SlideTransition(
                position: AppAnimations.slideInFromBottom(_slideController),
                child: FadeTransition(
                  opacity: _fadeController,
                  child: ScaleTransition(
                    scale: AppAnimations.scaleIn(_scaleController),
                    child: const _RoleList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatefulWidget {
  const _TopBar();

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> with SingleTickerProviderStateMixin {
  late AnimationController _wifiAnimationController;

  @override
  void initState() {
    super.initState();
    _wifiAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _wifiAnimationController.repeat();
  }

  @override
  void dispose() {
    _wifiAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WifiCubit, WifiState>(
      builder: (context, state) {
        final isConnected = state is WifiConnected || state is WifiConnectedStable;
        final wifiIcon = isConnected ? AppIcons.wifi2() : AppIcons.wifi1();
        final msg = isConnected ? 'Wi-Fi подключён' : 'Wi-Fi отключён';

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.s),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TopButton(
                icon: isConnected
                    ? wifiIcon
                    : AppIcons.animatedIcon(
                  icon: wifiIcon,
                  controller: _wifiAnimationController,
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      backgroundColor: isConnected ? AppColors.success : AppColors.warning,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppBorderRadius.s,
                      ),
                    ),
                  );
                },
              ),
              Row(
                children: [
                  _TopButton(
                    icon: AppIcons.settings(),
                    onTap: () => Navigator.push(
                      context,
                      SlideTransitionPage(
                        direction: SlideDirection.right,
                        child: const SettingsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  _TopButton(
                    icon: AppIcons.profile(),
                    onTap: () => Navigator.push(
                      context,
                      SlideTransitionPage(
                        direction: SlideDirection.right,
                        child: const ProfileScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback onTap;
  const _TopButton({required this.icon, required this.onTap});

  @override
  State<_TopButton> createState() => _TopButtonState();
}

class _TopButtonState extends State<_TopButton> with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: AppAnimations.fast,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: AppBorderRadius.xs,
                boxShadow: AppShadows.light,
              ),
              alignment: Alignment.center,
              child: widget.icon,
            ),
          );
        },
      ),
    );
  }
}

class _InspirationBanner extends StatefulWidget {
  const _InspirationBanner();

  @override
  State<_InspirationBanner> createState() => _InspirationBannerState();
}

class _InspirationBannerState extends State<_InspirationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: AppBorderRadius.m,
          boxShadow: AppShadows.light,
        ),
        padding: const EdgeInsets.all(AppSpacing.s),
        child: Stack(
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/diamond.png',
                  width: 103,
                  height: 71,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shine Inspiration',
                        style: AppTextStyles.lead
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'Лучшие фото от пользователей\nдля вашего вдохновения',
                        style: AppTextStyles.hintAccent.copyWith(
                          color: AppColors.primary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleList extends StatelessWidget {
  const _RoleList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      itemCount: 2,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xl),
      itemBuilder: (context, index) {
        final isHost = index == 0;

        return _RoleCard(
          image: isHost
              ? 'assets/images/camera2.png'
              : 'assets/images/camera.png',
          label: isHost ? 'Я фотографирую' : 'Меня фотографируют',
          animationDelay: Duration(milliseconds: index * 200),
          onTap: () async {
            final wifiState = context.read<WifiCubit>().state;

            if (!isHost) {
              final needHostTip = await HostTipScreen.shouldShow() ||
                  wifiState is WifiDisconnected;

              if (needHostTip) {
                await Navigator.push(
                  context,
                  SlideTransitionPage(
                    direction: SlideDirection.up,
                    child: const HostTipScreen(),
                  ),
                );
                return;
              }

              context.read<RoleCubit>().selectHost();
              Navigator.push(
                context,
                SlideTransitionPage(
                  direction: SlideDirection.right,
                  child: const ReceiverScreen(),
                ),
              );
            } else {
              final needClientTip = await ClientTipScreen.shouldShow() ||
                  wifiState is WifiDisconnected;

              if (needClientTip) {
                await Navigator.push(
                  context,
                  SlideTransitionPage(
                    direction: SlideDirection.up,
                    child: const ClientTipScreen(),
                  ),
                );
                return;
              }

              context.read<RoleCubit>().selectClient();
              Navigator.push(
                context,
                SlideTransitionPage(
                  direction: SlideDirection.right,
                  child: const HostSelectionScreen(),
                ),
              );
            }
          },
        );
      },
    );
  }
}

class _RoleCard extends StatefulWidget {
  final String image;
  final String label;
  final Duration animationDelay;
  final VoidCallback onTap;

  const _RoleCard({
    required this.image,
    required this.label,
    required this.animationDelay,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _pressController;
  late Animation<double> _hoverAnimation;
  late Animation<double> _pressAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();

    _hoverController = AnimationController(
      duration: AppAnimations.normal,
      vsync: this,
    );

    _pressController = AnimationController(
      duration: AppAnimations.fast,
      vsync: this,
    );

    _hoverAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );

    _pressAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    _elevationAnimation = Tween<double>(begin: 2.0, end: 8.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _pressController.forward();
        HapticFeedback.mediumImpact();
      },
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => _hoverController.forward(),
        onExit: (_) => _hoverController.reverse(),
        child: AnimatedBuilder(
          animation: Listenable.merge([_hoverAnimation, _pressAnimation]),
          builder: (context, child) {
            return Transform.scale(
              scale: _hoverAnimation.value * _pressAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppSpacing.s),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: _elevationAnimation.value,
                      offset: Offset(0, _elevationAnimation.value / 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.l,
                  horizontal: AppSpacing.s,
                ),
                child: Column(
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: widget.animationDelay,
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Transform.rotate(
                            angle: (1 - value) * 0.1,
                            child: Image.asset(
                              widget.image,
                              width: 164,
                              height: 144,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.s),
                    TweenAnimationBuilder<double>(
                      duration: widget.animationDelay + const Duration(milliseconds: 200),
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Text(
                              widget.label,
                              style: AppTextStyles.h2
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
