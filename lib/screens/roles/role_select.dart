import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shine/screens/profile_screen.dart';
import 'package:shine/screens/settings/settings_screen.dart';
import '../../blocs/role/role_cubit.dart';
import '../../blocs/wifi/wifi_cubit.dart';
import '../../blocs/wifi/wifi_state.dart';
import '../../theme/main_design.dart';
import 'ReceiverScreen.dart';
import '../tip_screen/client_tip_screen.dart';
import '../tip_screen/host_tip_screen.dart';

import 'host_selection_screen.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: const [
            _TopBar(),
            SizedBox(height: AppSpacing.xl),
            _InspirationBanner(),
            SizedBox(height: AppSpacing.xl),
            Expanded(child: _RoleList()),
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
        final wifiIcon = state is WifiConnected || state is WifiConnectedStable
            ? AppIcons.wifi2()
            : AppIcons.wifi1();

        final msg = state is WifiConnected || state is WifiConnectedStable
            ? 'Wi-Fi подключён'
            : 'Wi-Fi отключён';

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.s),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TopButton(
                icon: wifiIcon,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg)),
                  );
                },
              ),
              Row(
                children: [
                  _TopButton(
                    icon: AppIcons.settings(),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  _TopButton(
                    icon: AppIcons.profile(),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
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

class _TopButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;
  const _TopButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppBorderRadius.xs,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: AppBorderRadius.xs,
        ),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }
}

class _InspirationBanner extends StatelessWidget {
  const _InspirationBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.premmarylight,
          borderRadius: AppBorderRadius.m,
        ),
        padding: const EdgeInsets.all(AppSpacing.s),
        child: Row(
          children: [
            Image.asset('assets/images/diamond.png', width: 103, height: 71),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shine Inspiration',
                    style: AppTextStyles.lead,
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Лучшие фото от пользователей\nдля вашего вдохновения',
                    style: AppTextStyles.hintAccent,
                  ),
                ],
              ),
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
          onTap: () async {
            final wifiState = context.read<WifiCubit>().state;

            if (!isHost) {
              final needHostTip = await HostTipScreen.shouldShow() ||
                  wifiState is WifiDisconnected;

              if (needHostTip) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HostTipScreen()),
                );
                return;
              }

              context.read<RoleCubit>().selectHost();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReceiverScreen()),
              );
            } else {
              final needClientTip = await HostTipScreen.shouldShow() ||
                  wifiState is WifiDisconnected;

              if (needClientTip) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClientTipScreen()),
                );
                return;
              }

              context.read<RoleCubit>().selectClient();
             Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HostSelectionScreen()),
              );
            }
          },
        );

      },
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String image;
  final String label;
  final VoidCallback onTap;

  const _RoleCard({
    required this.image,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppSpacing.s),
        ),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.l,
          horizontal: AppSpacing.s,
        ),
        child: Column(
          children: [
            Image.asset(image, width: 164, height: 144),
            const SizedBox(height: AppSpacing.s),
            Text(label, style: AppTextStyles.h2),
          ],
        ),
      ),
    );
  }
}