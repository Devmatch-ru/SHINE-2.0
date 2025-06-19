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
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _initManager() async {
    await _manager.init();
    await _refreshList();
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
                MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
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
                      // Format the receiver URL
                      if (_selectedHost!.startsWith('RECEIVER:')) {
                        final parts = _selectedHost!.split(':');
                        if (parts.length == 3) {
                          final receiverIP = parts[1];
                          final receiverPort = parts[2];
                          final fullReceiverUrl =
                              'http://$receiverIP:$receiverPort';

                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BroadcasterScreen(
                                  receiverUrl: fullReceiverUrl),
                            ),
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
                      (host) => Column(
                        children: [
                          ListTile(
                            title: Text(host),
                            trailing: _selectedHost == host
                                ? const Icon(Icons.check, color: Colors.black)
                                : null,
                            onTap: () => _onSelect(host),
                          ),
                          if (host != _filteredHosts.last) _buildDivider(),
                        ],
                      ),
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
