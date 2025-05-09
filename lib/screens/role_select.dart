import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shine/screens/settings_screen.dart';
import '../blocs/role/role_cubit.dart';
class RoleSelect extends StatelessWidget {
  const RoleSelect({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: const [
            _TopBar(),
            SizedBox(height: 16),
            _InspirationBanner(),
            SizedBox(height: 24),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _TopButton(
            icon: Icons.wifi,
            onTap: () {
              // TODO: реализовать проверку WiFi / статус сети
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('WiFi status placeholder')),
              );
            },
          ),
          Row(
            children: [
              _TopButton(
                icon: Icons.settings,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const SizedBox(width: 16),
              _TopButton(
                icon: Icons.person,
                onTap: () {
                  // TODO: заменить на переход в профиль
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile placeholder')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 24, color: Colors.black),
        onPressed: onTap,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2FF),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Image.asset('assets/images/diamond.png', width: 48, height: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shine Inspiration',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Лучшие фото от пользователей\nдля вашего вдохновения',
                    style: theme.textTheme.bodyMedium,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 2,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final isHost = index == 0;
        return _RoleCard(
          image: 'assets/images/camera.png',
          label: isHost ? 'Я фотографирую' : 'Меня фотографируют',
          onTap: () => isHost
              ? context.read<RoleCubit>().selectHost()
              : context.read<RoleCubit>().selectClient(),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Image.asset(image, width: 120, height: 120),
            const SizedBox(height: 16),
            Text(label, style: theme.textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}
