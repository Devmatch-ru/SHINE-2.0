import 'package:flutter/material.dart';
import 'package:shine/screens/user/role_select.dart';
import '../../../theme/app_constant.dart';
import 'broadcaster_screen.dart';
import '../../../utils/broadcaster_manager.dart';
import 'dart:async';

class ReceiverDevice {
  final String id;
  final String displayName;
  final String ip;
  final String port;

  ReceiverDevice({
    required this.id,
    required this.displayName,
    required this.ip,
    required this.port,
  });

  String get fullUrl => 'http://$ip:$port';

  static ReceiverDevice? fromHostString(String host) {
    final parts = host.split(':');
    if (parts.length != 3 || !parts[0].startsWith('RECEIVER')) return null;

    return ReceiverDevice(
      id: host,
      displayName: _generateDisplayName(parts[1]),
      ip: parts[1],
      port: parts[2],
    );
  }

  static String _generateDisplayName(String ip) {
    const coolWords = [
      'Linker', 'Signal', 'Wave', 'Beam', 'Echo',
      'Pulse', 'Relay', 'Nimbus', 'Channel', 'Bridge',
    ];

    final parts = ip.split('.');
    if (parts.length != 4) return 'Unknown';

    final lastOctet = parts.last.replaceAll(RegExp(r'[^0-9]'), '');
    final index = int.tryParse(lastOctet) ?? 0;

    return '${coolWords[index % coolWords.length]}$lastOctet';
  }
}

class ReceiverSelectionScreen extends StatefulWidget {
  const ReceiverSelectionScreen({super.key});

  @override
  State<ReceiverSelectionScreen> createState() => _ReceiverSelectionScreenState();
}

class _ReceiverSelectionScreenState extends State<ReceiverSelectionScreen> {
  final _searchController = TextEditingController();
  final _animationKeys = <String, GlobalKey>{};

  late final BroadcasterManager _manager;
  Timer? _refreshTimer;

  String? _selectedDeviceId;
  bool _isSearching = false;
  List<ReceiverDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _initManager();
    _searchController.addListener(() => setState(() {}));
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _manager.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initManager() {
    _manager = BroadcasterManager(
      onStateChange: () {
        if (mounted) _updateDevicesList();
      },
    );
    _manager.init().then((_) => _refreshList());
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
          (_) => _refreshList(),
    );
  }

  Future<void> _refreshList() async {
    if (!mounted) return;

    setState(() => _isSearching = true);

    try {
      await _manager.refreshReceivers();
    } catch (e) {
      _showError('Ошибка обновления списка: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _updateDevicesList() {
    final newDevices = _manager.availableReceivers
        .map(ReceiverDevice.fromHostString)
        .where((device) => device != null)
        .cast<ReceiverDevice>()
        .toList();

    for (final device in newDevices) {
      if (!_animationKeys.containsKey(device.id)) {
        _animationKeys[device.id] = GlobalKey();
      }
    }

    setState(() => _devices = newDevices);
  }

  List<ReceiverDevice> get _filteredDevices {
    final query = _searchController.text.toLowerCase();
    return _devices
        .where((device) => device.displayName.toLowerCase().contains(query))
        .toList();
  }

  void _selectDevice(String deviceId) {
    setState(() => _selectedDeviceId = deviceId);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }


  Future<void> _connectToDevice() async {
    final device = _devices.firstWhere((d) => d.id == _selectedDeviceId);

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BroadcasterScreen(receiverUrl: device.fullUrl),
        ),
      );
    } catch (e) {
      _showError('Ошибка подключения: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AnimatedSection(
              delay: 0,
              child: _HeaderSection(isSearching: _isSearching),
            ),
            const SizedBox(height: 8),
            _AnimatedSection(
              delay: 200,
              child: _SearchAndListSection(
                controller: _searchController,
                devices: _filteredDevices,
                selectedDeviceId: _selectedDeviceId,
                onDeviceSelect: _selectDevice,
                animationKeys: _animationKeys,
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Отменить',
              style: AppTextStyles.lead.copyWith(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: _selectedDeviceId == null ? null : _connectToDevice,
            child: Text(
              'Готово',
              style: AppTextStyles.lead.copyWith(
                color: _selectedDeviceId == null ? Colors.grey : Colors.black,
              ),
            ),
          ),
        ],
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
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    );
    _slideY = Tween<double>(begin: 30.0, end: 0.0).animate(
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

class _HeaderSection extends StatelessWidget {
  final bool isSearching;

  const _HeaderSection({required this.isSearching});

  @override
  Widget build(BuildContext context) {
    return Row(
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
        if (isSearching)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
            ),
          ),
      ],
    );
  }
}

class _SearchAndListSection extends StatelessWidget {
  final TextEditingController controller;
  final List<ReceiverDevice> devices;
  final String? selectedDeviceId;
  final Function(String) onDeviceSelect;
  final Map<String, GlobalKey> animationKeys;

  const _SearchAndListSection({
    required this.controller,
    required this.devices,
    required this.selectedDeviceId,
    required this.onDeviceSelect,
    required this.animationKeys,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _SearchField(controller: controller),
          _buildDivider(),
          if (devices.isEmpty)
            const _EmptyState()
          else
            _DevicesList(
              devices: devices,
              selectedDeviceId: selectedDeviceId,
              onDeviceSelect: onDeviceSelect,
              animationKeys: animationKeys,
            ),
        ],
      ),
    );
  }

  Widget _buildDivider() => const Divider(
    height: 0,
    thickness: 0.5,
    indent: AppSpacing.s,
    color: Color(0xFFE0E0E0),
  );
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;

  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: const InputDecoration(
        hintText: 'Поиск...',
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: InputBorder.none,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'Устройства не найдены',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }
}

class _DevicesList extends StatelessWidget {
  final List<ReceiverDevice> devices;
  final String? selectedDeviceId;
  final Function(String) onDeviceSelect;
  final Map<String, GlobalKey> animationKeys;

  const _DevicesList({
    required this.devices,
    required this.selectedDeviceId,
    required this.onDeviceSelect,
    required this.animationKeys,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: devices
          .asMap()
          .entries
          .map((entry) => _AnimatedDeviceItem(
        key: animationKeys[entry.value.id],
        delay: entry.key * 100,
        device: entry.value,
        isSelected: selectedDeviceId == entry.value.id,
        onTap: () => onDeviceSelect(entry.value.id),
        showDivider: entry.key < devices.length - 1,
      ))
          .toList(),
    );
  }
}

class _AnimatedDeviceItem extends StatefulWidget {
  final int delay;
  final ReceiverDevice device;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showDivider;

  const _AnimatedDeviceItem({
    super.key,
    required this.delay,
    required this.device,
    required this.isSelected,
    required this.onTap,
    required this.showDivider,
  });

  @override
  State<_AnimatedDeviceItem> createState() => _AnimatedDeviceItemState();
}

class _AnimatedDeviceItemState extends State<_AnimatedDeviceItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _slideX;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    );
    _slideX = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    Future.delayed(Duration(milliseconds: 400 + widget.delay), () {
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
          child: Transform.scale(
            scale: _scale.value,
            child: Transform.translate(
              offset: Offset(_slideX.value, 0),
              child: Column(
                children: [
                  ListTile(
                    title: Text(widget.device.displayName),
                    trailing: widget.isSelected
                        ? const Icon(Icons.check, color: Colors.black)
                        : null,
                    onTap: widget.onTap,
                  ),
                  if (widget.showDivider) _buildDivider(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDivider() => const Divider(
    height: 0,
    thickness: 0.5,
    indent: AppSpacing.s,
    color: Color(0xFFE0E0E0),
  );
}