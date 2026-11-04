import 'package:flutter/material.dart';

import 'app_push_bridge.dart';
import 'push_bridge_stub.dart'
    if (dart.library.io) 'push_bridge_io.dart' as platform;

export 'app_push_bridge.dart';

/// Điểm vào duy nhất cho push: chọn bản io hay stub tuỳ nền tảng biên dịch.
AppPushBridge? createPushBridge({
  required String baseUrl,
  required GlobalKey<ScaffoldMessengerState> messengerKey,
}) => platform.createPushBridge(baseUrl: baseUrl, messengerKey: messengerKey);
