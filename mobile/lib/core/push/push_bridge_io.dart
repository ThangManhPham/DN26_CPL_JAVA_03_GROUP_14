import 'package:flutter/material.dart';

import '../../push_bridge.dart';
import 'app_push_bridge.dart';

/// iOS/Android: bọc `PushBridge` sẵn có của M1/M5 trong interface chung.
AppPushBridge? createPushBridge({
  required String baseUrl,
  required GlobalKey<ScaffoldMessengerState> messengerKey,
}) => _PushBridgeAdapter(
  PushBridge(baseUrl: baseUrl, messengerKey: messengerKey),
);

class _PushBridgeAdapter implements AppPushBridge {
  _PushBridgeAdapter(this._bridge);

  final PushBridge _bridge;

  @override
  Future<void> activate(String authToken) => _bridge.activate(authToken);

  @override
  Future<void> deactivate(String authToken) => _bridge.deactivate(authToken);

  @override
  Future<void> dispose() => _bridge.dispose();
}
