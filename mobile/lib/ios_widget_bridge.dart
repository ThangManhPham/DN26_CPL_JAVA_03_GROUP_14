import 'package:flutter/services.dart';

class IosWidgetBridge {
  static const _channel = MethodChannel('com.ourspace.mobile/widget');

  static Future<void> showPhoto(Uint8List bytes) async {
    try {
      await _channel.invokeMethod<void>('showPhoto', bytes);
    } on MissingPluginException {
      // WidgetKit is unavailable in tests.
    } on PlatformException {
      // The in-app image remains available if the widget cannot refresh.
    }
  }

  static Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      // WidgetKit is unavailable in tests.
    } on PlatformException {
      // Logout still succeeds if the widget cannot refresh.
    }
  }
}
