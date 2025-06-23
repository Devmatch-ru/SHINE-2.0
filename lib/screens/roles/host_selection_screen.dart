// lib/screens/roles/host_selection_screen.dart (Updated)
import 'package:flutter/material.dart';
import 'dart:async';

import '../../theme/app_constant.dart';
import '../../utils/broadcaster_manager.dart';
import '../../utils/app_utils.dart';
import '../../utils/service/error_handling_service.dart';
import '../../utils/service/logging_service.dart';
import './role_select.dart';
import './BroadcasterScreen.dart';

class HostSelectionScreen extends StatefulWidget {
  const HostSelectionScreen({super.key});

  @override
  State<HostSelectionScreen> createState() => _HostSelectionScreenState();
}

class _HostSelectionScreenState extends State<HostSelectionScreen>
    with LoggerMixin, ErrorHandlerMixin {

  @override
  String get loggerContext => 'HostSelectionScreen';

  final TextEditingController _searchController = TextEditingController();
  String? _selectedHost;
  bool _isSearching = false;
  late final BroadcasterManager _manager;
  Timer? _refreshTimer;
  final UserNameGenerator _nameGenerator = UserNameGenerator();

  @override
  void initState() {
    super.initState();
    _initializeManager();
    _searchController.addListener(_onSearchChanged);
    _startPeriodicRefresh();
  }

  void _initializeManager() {
    try {
      logInfo('Initializing broadcaster manager for host selection...');

      _manager = BroadcasterManager(
        onStateChange: () {
          if (mounted) setState(() {});
        },
        onError: _handleManagerError,
      );

      _initManager();
    } catch (e, stackTrace) {
      handleError('_initializeManager', e, stackTrace: stackTrace);
    }
  }

  void _handleManagerError(String error) {
    logError('Manager error: $error');
    handleUserError('BroadcasterManager', error);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $error')),
      );
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (mounted && !_isSearching) {
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
      logDebug('Refreshing receiver list...');
      await _manager.refreshReceivers();
      logDebug('Receiver list refreshed, found: ${_manager.availableReceivers.length}');
    } catch (e, stackTrace) {
      handleNetworkError('_refreshList', e, stackTrace: stackTrace);

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
      logInfo('Initializing manager...');
      await _manager.init();
      await _refreshList();
      logInfo('Manager initialized successfully');
    } catch (e, stackTrace) {
      handleError('_initManager', e, stackTrace: stackTrace);

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
    try {
      logInfo('Selected host: $host');
      setState(() {
        _selectedHost = host;
      });
    } catch (e, stackTrace) {
      handleError('_onSelect', e, stackTrace: stackTrace);
    }
  }

  List<String> get _filteredHosts {
    final query = _searchController.text.toLowerCase();
    return _manager.availableReceivers
        .where((host) {
      final hostLower = host.toLowerCase();
      final userName = _nameGenerator.generateFromReceiverInfo(host).toLowerCase();
      return hostLower.contains(query) || userName.contains(query);
    })
        .toList();
  }

  Widget _buildDivider() => const Divider(
    height: 0,
    thickness: 0.5,
    indent: AppSpacing.s,
    color: Color(0xFFE0E0E0),
  );

  Future<void> _navigateToBroadcaster() async {
    if (_selectedHost == null) return;

    try {
      logInfo('Navigating to broadcaster screen...');

      final receiverInfo = _manager.availableReceivers
          .firstWhere((host) => host == _selectedHost);

      if (receiverInfo.startsWith('RECEIVER:')) {
        final parts = receiverInfo.split(':');
        if (parts.length == 3) {
          final receiverIP = parts[1];
          final receiverPort = parts[2];
          final fullReceiverUrl = 'http://$receiverIP:$receiverPort';

          logInfo('Connecting to: $fullReceiverUrl');

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BroadcasterScreen(receiverUrl: fullReceiverUrl),
            ),
          );
        } else {
          throw Exception('Invalid receiver URL format');
        }
      } else {
        throw Exception('Invalid receiver response format');
      }
    } catch (e, stackTrace) {
      handleError('_navigateToBroadcaster', e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка перехода: $e')),
        );
      }
    }
  }

  Widget _buildReceiverListItem(String host) {
    try {
      final userName = _nameGenerator.generateFromReceiverInfo(host);
      final isSelected = _selectedHost == host;

      return Column(
        children: [
          ListTile(
            title: Text(
              userName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              host.split(':')[1], // Show IP address
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.check, color: Colors.black)
                : null,
            onTap: () => _onSelect(host),
          ),
          if (host != _filteredHosts.last) _buildDivider(),
        ],
      );
    } catch (e, stackTrace) {
      handleError('_buildReceiverListItem', e, stackTrace: stackTrace);

      return ListTile(
        title: const Text('Unknown Device'),
        subtitle: const Text('Error parsing device info'),
        onTap: () => _onSelect(host),
      );
    }
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.wifi_tethering,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Устройства не найдены',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Убедитесь, что другое устройство подключено к той же Wi-Fi сети и запустило режим "Меня фотографируют"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshList,
            icon: const Icon(Icons.refresh),
            label: const Text('Обновить'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    try {
      logInfo('Disposing host selection screen...');

      _refreshTimer?.cancel();
      _searchController.dispose();
      _manager.dispose();

      logInfo('Host selection screen disposed');
    } catch (e, stackTrace) {
      handleError('dispose', e, stackTrace: stackTrace);
    }

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
              onPressed: () async {
                try {
                  logInfo('Navigating back to role selection...');
                  await Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 300),
                      pageBuilder: (context, animation, secondaryAnimation) =>
                      const RoleSelectScreen(),
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
                  );
                } catch (e, stackTrace) {
                  handleError('navigation_back', e, stackTrace: stackTrace);
                }
              },
              child: Text(
                'Отменить',
                style: AppTextStyles.lead.copyWith(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: _selectedHost == null ? null : _navigateToBroadcaster,
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
                Row(
                  children: [
                    if (_filteredHosts.isNotEmpty)
                      Text(
                        '${_filteredHosts.length}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (_isSearching)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _refreshList,
                        child: Icon(
                          Icons.refresh,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
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
                      hintText: 'Поиск по названию...',
                      prefixIcon: Icon(Icons.search),
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: InputBorder.none,
                    ),
                  ),
                  _buildDivider(),

                  if (_filteredHosts.isEmpty && !_isSearching)
                    _buildEmptyState()
                  else if (_filteredHosts.isEmpty && _isSearching)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Поиск устройств...'),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: _filteredHosts.map(_buildReceiverListItem).toList(),
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