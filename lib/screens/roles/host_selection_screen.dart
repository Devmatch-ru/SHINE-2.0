import 'package:flutter/material.dart';
import 'package:shine/screens/roles/role_select.dart';
import '../../theme/main_design.dart';
import 'BroadcasterScreen.dart';
import '../../utils/broadcaster_manager.dart';
import 'dart:async';

class HostSelectionScreen extends StatefulWidget {
  const HostSelectionScreen({super.key});

  @override
  State<HostSelectionScreen> createState() => _HostSelectionScreenState();
}

class _HostSelectionScreenState extends State<HostSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedHost;
  bool _isSearching = false;
  late final BroadcasterManager _manager;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _manager = BroadcasterManager(
      onStateChange: () {
        if (mounted) setState(() {});
      },
    );
    _initManager();
    _searchController.addListener(_onSearchChanged);
    _startPeriodicRefresh();
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (mounted) {
        await _refreshList();
      }
    });
  }

  Future<void> _refreshList() async {
    if (!mounted) return;

    setState(() {
      _isSearching = true;
    });

    try {
      await _manager.refreshReceivers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления списка: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _initManager() async {
    try {
      await _manager.init();
      await _refreshList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка инициализации: $e')),
        );
      }
    }
  }

  void _onSearchChanged() {
    setState(() {});
  }

  void _onSelect(String host) {
    setState(() {
      _selectedHost = host;
    });
  }

  List<String> get _filteredHosts {
    final query = _searchController.text.toLowerCase();
    return _manager.availableReceivers
        .where((host) => host.toLowerCase().contains(query))
        .toList();
  }

  Widget _buildDivider() => const Divider(
    height: 0,
    thickness: 0.5,
    indent: AppSpacing.s,
    color: Color(0xFFE0E0E0),
  );

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _manager.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () async => await Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 300),
                  pageBuilder: (context, animation, secondaryAnimation) => const RoleSelectScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: animation.drive(
                        Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                            .chain(CurveTween(curve: Curves.easeInOut)),
                      ),
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                ),
              ),
              child: Text(
                'Отменить',
                style: AppTextStyles.lead.copyWith(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: _selectedHost == null
                  ? null
                  : () async {
                if (_selectedHost!.startsWith('RECEIVER:')) {
                  final parts = _selectedHost!.split(':');
                  if (parts.length == 3) {
                    final receiverIP = parts[1];
                    final receiverPort = parts[2];
                    final fullReceiverUrl = 'http://$receiverIP:$receiverPort';
                    try {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BroadcasterScreen(receiverUrl: fullReceiverUrl),
                        ),
                      );
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ошибка перехода: $e')),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Неверный формат адреса приемника')),
                    );
                  }
                }
              },
              child: Text(
                'Готово',
                style: AppTextStyles.lead.copyWith(
                  color: _selectedHost == null ? Colors.grey : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ВЫБЕРИ УЧАСТНИКА',
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.black,
                    letterSpacing: 0.5,
                  ),
                ),
                if (_isSearching)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Поиск...',
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: InputBorder.none,
                    ),
                  ),
                  _buildDivider(),
                  if (_filteredHosts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Устройства не найдены',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._filteredHosts.map(
                          (host) {
                        final UserName = _generateUserNameText(host);
                        return Column(
                          children: [
                            ListTile(
                              title: Text(UserName),
                              trailing: _selectedHost == host
                                  ? const Icon(Icons.check, color: Colors.black)
                                  : null,
                              onTap: () => _onSelect(host),
                            ),
                            if (host != _filteredHosts.last) _buildDivider(),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _generateUserNameText(String host) {
    const coolWords = [
      'Linker',
      'Signal',
      'Wave',
      'Beam',
      'Echo',
      'Pulse',
      'Relay',
      'Nimbus',
      'Channel',
      'Bridge',
    ];

    final parts = host.split(':');
    if (parts.length != 3) return 'Unknown';

    final ip = parts[1];
    final ipParts = ip.split('.');
    if (ipParts.length != 4) return 'Unknown';

    final lastOctet = ipParts.last;
    final lastDigits = lastOctet.replaceAll(RegExp(r'[^0-9]'), '');

    final index = int.tryParse(lastDigits) ?? 0;
    final word = coolWords[index % coolWords.length];

    return '$word$lastDigits';
  }
}