import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'wifi_state.dart';

class WifiCubit extends Cubit<WifiState> {
  final Connectivity _connectivity;
  final InternetConnectionChecker _internetChecker;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _pingTimer;

  WifiCubit({Connectivity? connectivity, InternetConnectionChecker? internetChecker})
      : _connectivity = connectivity ?? Connectivity(),
        _internetChecker = internetChecker ?? InternetConnectionChecker.createInstance(),
        super(WifiInitial()) {
    _init();
  }

  Future<void> _init() async {
    try {
      _connSub = _connectivity.onConnectivityChanged.listen(_handleConnectivityList);
      final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
      _handleConnectivityList(results);
    } catch (e) {
      debugPrint('Ошибка при инициализации: $e');
      emit(WifiDisconnected());
    }
  }

  void _handleConnectivityList(List<ConnectivityResult> results) {
    debugPrint('Результаты подключения: $results');
    if (results.contains(ConnectivityResult.wifi)) {
      debugPrint('Wi-Fi подключен');
      emit(WifiConnected());
      _startInternetChecks();
    } else {
      debugPrint('Wi-Fi отключен');
      _pingTimer?.cancel();
      emit(WifiDisconnected());
    }
  }

  void _startInternetChecks() {
    _checkInternet();

    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => _checkInternet(),
    );
  }

  Future<void> _checkInternet() async {
    try {
      final bool hasConnection = await _internetChecker.hasConnection;
      if (state is WifiConnected || state is WifiConnectedStable || state is WifiConnectedUnstable) {
        debugPrint('Проверка интернета: ${hasConnection ? "стабильное" : "нестабильное"}');
        emit(hasConnection ? WifiConnectedStable() : WifiConnectedUnstable());
      }
    } catch (e) {
      debugPrint('Ошибка проверки интернета: $e');
      if (state is WifiConnected || state is WifiConnectedStable || state is WifiConnectedUnstable) {
        emit(WifiConnectedUnstable());
      }
    }
  }

  @override
  Future<void> close() async {
    await _connSub?.cancel();
    _pingTimer?.cancel();
    return super.close();
  }
}