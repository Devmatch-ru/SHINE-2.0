import 'package:flutter_webrtc/flutter_webrtc.dart';

enum Role { host, client }

class PeerModel {
  final String id;
  final Role role;
  MediaStream? stream;

  PeerModel({required this.id, required this.role, this.stream});
}
