import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'calendar_repository.dart';

/// iOS owns the opt-in and pending requests; no account data is stored on web.
/// Missing native support never prevents the shared calendar from loading.
class AnniversaryNotifications {
  const AnniversaryNotifications();
  static const channel = MethodChannel('com.ourspace.mobile/anniversary');
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<String> sync(CoupleSpace space, {bool? enabled}) async {
    if (!supported) return 'unsupported';
    try {
      return await channel.invokeMethod<String>('sync', {
            'coupleId': space.coupleId,
            'anniversaryDate': space.anniversary == null
                ? null
                : '${space.anniversary!.year.toString().padLeft(4, '0')}-${space.anniversary!.month.toString().padLeft(2, '0')}-${space.anniversary!.day.toString().padLeft(2, '0')}',
            'enabled': ?enabled,
          }) ??
          'unavailable';
    } on MissingPluginException {
      return 'unsupported';
    } on PlatformException {
      return 'unavailable';
    }
  }

  Future<void> clear() async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      // Widget tests and older native binaries may not register this channel.
    } on PlatformException {
      // Logout must still finish if the OS notification API is unavailable.
    }
  }
}
