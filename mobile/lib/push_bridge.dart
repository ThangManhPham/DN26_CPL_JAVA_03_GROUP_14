import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Registers only the currently authenticated user's device. No token is sent
/// to the backend before login, and logout removes the registration.
class PushBridge {
  PushBridge({required String baseUrl, required this.messengerKey})
    : _base = Uri.parse(baseUrl) {
    _refreshSubscription = FirebaseMessaging.instance.onRegistered.listen(
      (token) => _register(token),
    );
    _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
      if (_authToken == null || message.data['type'] != 'photo') return;
      messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Người yêu vừa gửi một ảnh mới 💕')),
      );
    });
  }

  final Uri _base;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  late final StreamSubscription<String> _refreshSubscription;
  late final StreamSubscription<RemoteMessage> _messageSubscription;
  String? _authToken;
  String? _deviceToken;

  Future<void> activate(String authToken) async {
    _authToken = authToken;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (Platform.isIOS) {
        for (var attempt = 0; attempt < 5; attempt++) {
          if (_authToken != authToken) return;
          if (await FirebaseMessaging.instance.getAPNSToken() != null) break;
          await Future<void>.delayed(const Duration(seconds: 2));
        }
        if (await FirebaseMessaging.instance.getAPNSToken() == null) return;
      }
      await FirebaseMessaging.instance.register();
    } catch (_) {
      // Notification setup must never block login or photo sharing.
    }
  }

  Future<void> _register(String deviceToken) async {
    final authToken = _authToken;
    if (authToken == null) return;
    try {
      final response = await http
          .put(
            _base.resolve('/api/v1/devices/push-token'),
            headers: {
              'Authorization': 'Bearer $authToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'token': deviceToken,
              'platform': Platform.isIOS ? 'ios' : 'android',
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 204) {
        if (_authToken != authToken) {
          await _removeFor(authToken, deviceToken);
        } else {
          final oldToken = _deviceToken;
          _deviceToken = deviceToken;
          if (oldToken != null && oldToken != deviceToken) {
            await _removeFor(authToken, oldToken);
          }
        }
      }
    } catch (_) {
      // Registration can retry on a later token refresh or login.
    }
  }

  Future<void> deactivate(String authToken) async {
    _authToken = null;
    final deviceToken = _deviceToken;
    _deviceToken = null;
    if (deviceToken != null) await _removeFor(authToken, deviceToken);
    if (_authToken != null) return;
    try {
      await FirebaseMessaging.instance.unregister();
    } catch (_) {
      // A server-side token may remain until it expires, but carries no image data.
    }
  }

  Future<void> _removeFor(String authToken, String deviceToken) async {
    try {
      await http
          .delete(
            _base.resolve('/api/v1/devices/push-token'),
            headers: {
              'Authorization': 'Bearer $authToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'token': deviceToken,
              'platform': Platform.isIOS ? 'ios' : 'android',
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // The server JWT expires; keep push payloads non-sensitive and generic.
    }
  }

  Future<void> dispose() async {
    await _refreshSubscription.cancel();
    await _messageSubscription.cancel();
  }
}
