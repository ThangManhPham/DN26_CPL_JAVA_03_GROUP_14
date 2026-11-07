import 'package:flutter/material.dart';

import 'app_push_bridge.dart';

/// Bản stub cho nền tảng không hỗ trợ push (web). Trả `null` để app bỏ qua
/// phần thông báo mà không thay đổi luồng đăng nhập.
AppPushBridge? createPushBridge({
  required String baseUrl,
  required GlobalKey<ScaffoldMessengerState> messengerKey,
}) => null;
