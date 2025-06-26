import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/role/role_cubit.dart';
import '../../blocs/wifi/wifi_cubit.dart';
import '../../blocs/wifi/wifi_state.dart';
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';
import '../../theme/dimensions.dart';
import '../../theme/icons.dart';
import '../../widgets/common/slide_transition_page.dart';
import 'profile_screen.dart';
import 'receiver/receiver_screen.dart';
import '../settings/settings_screen.dart';
import '../tip_screen/broadcaster_tip_screen.dart';
import '../tip_screen/receiver_tip_screen.dart';
import 'broadcaster/receiver_select_screen.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            const SizedBox(height: AppSpacing.xl),
            const SizedBox(height: AppSpacing.xl),
            const Expanded(child: _RoleList()),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WifiCubit, WifiState>(
      builder: (context, state) {
        final isWifiConnected = state is WifiConnected || state is WifiConnectedStable;
        final statusMessage = isWifiConnected ? 'Wi-Fi подключён' : 'Wi-Fi отключён';

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.s),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AnimatedButton(
                delay: 0,
                icon: isWifiConnected ? AppIcons.wifi2() : AppIcons.wifi1(),
                onTap: () => _showWifiStatus(context, isWifiConnected, statusMessage),
              ),
              Row(
                children: [
                  _AnimatedButton(
                    delay: 200,
                    icon: AppIcons.settings(),
                    onTap: () => _navigateTo(context, const SettingsScreen()),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  _AnimatedButton(
                    delay: 400,
                    icon: AppIcons.profile(),
                    onTap: () => _navigateTo(context, const ProfileScreen()),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWifiStatus(BuildContext context, bool isConnected, String message) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isConnected ? AppColors.success : AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.s),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
        context,
        SlideTransitionPage(direction: SlideDirection.right, child: screen)
    );
  }
}

class _AnimatedButton extends StatefulWidget {
  final int delay;
  final Widget icon;
  final VoidCallback onTap;

  const _AnimatedButton({
    required this.delay,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
    with TickerProviderStateMixin {
  late AnimationController _appearController;
  late AnimationController _tapController;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _appearController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _tapController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _opacity = CurvedAnimation(
      parent: _appearController,
      curve: Curves.easeOutQuart,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _appearController.forward();
    });
  }

  @override
  void dispose() {
    _appearController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_opacity, _scale]),
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: GestureDetector(
              onTapDown: (_) => _tapController.forward(),
              onTapUp: (_) => _tapController.reverse(),
              onTapCancel: () => _tapController.reverse(),
              onTap: widget.onTap,
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
            ),
          ),
        );
      },
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
        final isHostRole = index == 0;
        return _AnimatedRoleCard(
          delay: 600 + (index * 300),
          image: isHostRole ? 'assets/images/camera2.png' : 'assets/images/camera.png',
          label: isHostRole ? 'Я фотографирую' : 'Меня фотографируют',
          onTap: () => _handleRoleSelection(context, isHostRole),
        );
      },
    );
  }

  void _handleRoleSelection(BuildContext context, bool isHostRole) async {
    final wifiState = context.read<WifiCubit>().state;
    final roleCubit = context.read<RoleCubit>();
    final isWifiDisconnected = wifiState is WifiDisconnected;

    if (isHostRole) {
      final shouldShowTip = await ClientTipScreen.shouldShow() || isWifiDisconnected;
      if (shouldShowTip) {
        await Navigator.push(
          context,
          SlideTransitionPage(direction: SlideDirection.up, child: const ClientTipScreen()),
        );
        return;
      }
      roleCubit.selectHost();
      Navigator.push(
        context,
        SlideTransitionPage(direction: SlideDirection.right, child: const ReceiverSelectionScreen()),
      );
    } else {
      final shouldShowTip = await HostTipScreen.shouldShow() || isWifiDisconnected;
      if (shouldShowTip) {
        await Navigator.push(
          context,
          SlideTransitionPage(direction: SlideDirection.up, child: const HostTipScreen()),
        );
        return;
      }
      roleCubit.selectClient();
      Navigator.push(
        context,
        SlideTransitionPage(direction: SlideDirection.right, child: const ReceiverScreen()),
      );
    }
  }
}

class _AnimatedRoleCard extends StatefulWidget {
  final int delay;
  final String image;
  final String label;
  final VoidCallback onTap;

  const _AnimatedRoleCard({
    required this.delay,
    required this.image,
    required this.label,
    required this.onTap,
  });

  @override
  State<_AnimatedRoleCard> createState() => _AnimatedRoleCardState();
}

class _AnimatedRoleCardState extends State<_AnimatedRoleCard>
    with TickerProviderStateMixin {
  late AnimationController _appearController;
  late AnimationController _tapController;
  late Animation<double> _opacity;
  late Animation<double> _slideY;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _appearController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _tapController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _opacity = CurvedAnimation(
      parent: _appearController,
      curve: Curves.easeOutQuart,
    );
    _slideY = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _appearController, curve: Curves.easeOutQuart),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _appearController.forward();
    });
  }

  @override
  void dispose() {
    _appearController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_opacity, _slideY, _scale]),
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _slideY.value),
            child: Transform.scale(
              scale: _scale.value,
              child: GestureDetector(
                onTapDown: (_) => _tapController.forward(),
                onTapUp: (_) => _tapController.reverse(),
                onTapCancel: () => _tapController.reverse(),
                onTap: widget.onTap,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppSpacing.s),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.l, horizontal: AppSpacing.s),
                  child: Column(
                    children: [
                      Image.asset(widget.image, width: 164, height: 144),
                      const SizedBox(height: AppSpacing.s),
                      Text(widget.label, style: AppTextStyles.h2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}