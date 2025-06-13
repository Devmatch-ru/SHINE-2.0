abstract class WifiState {}

class WifiInitial extends WifiState {
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WifiInitial;

  @override
  int get hashCode => runtimeType.hashCode;
}

class WifiConnected extends WifiState {
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WifiConnected;

  @override
  int get hashCode => runtimeType.hashCode;
}

class WifiDisconnected extends WifiState {
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WifiDisconnected;

  @override
  int get hashCode => runtimeType.hashCode;
}

class WifiConnectedStable extends WifiState {
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WifiConnectedStable;

  @override
  int get hashCode => runtimeType.hashCode;
}

class WifiConnectedUnstable extends WifiState {
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WifiConnectedUnstable;

  @override
  int get hashCode => runtimeType.hashCode;
}