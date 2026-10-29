import 'package:flutter/services.dart';

class WidgetBridge {
  static const _channel = MethodChannel('com.ourspace.mobile/widget');

  static Future<void> showPhoto(Uint8List bytes) async {
    try {
      await _channel.invokeMethod<void>('showPhoto', bytes);
    } on MissingPluginException {
      // Widget is Android-only until the iOS WidgetKit target is configured.
    } on PlatformException {
      // Widget refresh is best-effort; in-app photo remains available.
    }
  }

  static Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      // No native widget on this platform.
    } on PlatformException {
      // Logout still proceeds if launcher widget refresh fails.
    }
  }
}
