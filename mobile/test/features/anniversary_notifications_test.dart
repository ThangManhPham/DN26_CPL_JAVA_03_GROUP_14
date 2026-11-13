import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/data/anniversary_notifications.dart';
import 'package:mobile/features/calendar/data/calendar_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const notifications = AnniversaryNotifications();
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls.clear();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AnniversaryNotifications.channel, null);
  });
  void handle(Future<Object?> Function(MethodCall) callback) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AnniversaryNotifications.channel, (
          call,
        ) async {
          calls.add(call);
          return callback(call);
        });
  }

  test(
    'sync preserves opt-in unless explicitly changed and sends a civil date, no token',
    () async {
      handle((_) async => 'enabled');
      final space = CoupleSpace(
        coupleId: 'ab',
        anniversary: DateTime(2020, 2, 29),
      );
      expect(await notifications.sync(space), 'enabled');
      expect(calls.last.arguments, {
        'coupleId': 'ab',
        'anniversaryDate': '2020-02-29',
      });
      await notifications.sync(space, enabled: false);
      expect(calls.last.arguments['enabled'], false);
      await notifications.clear();
      expect(calls.last.method, 'clear');
    },
  );
  test('permission denial is not reported as enabled', () async {
    handle((_) async => 'denied');
    expect(
      await notifications.sync(
        const CoupleSpace(coupleId: 'ab'),
        enabled: true,
      ),
      'denied',
    );
  });
  test('native failure does not break calendar or logout', () async {
    handle((_) async => throw PlatformException(code: 'FAILED'));
    expect(
      await notifications.sync(const CoupleSpace(coupleId: 'ab')),
      'unavailable',
    );
    await notifications.clear();
  });
  test('unsupported platforms do not invoke native APIs', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    handle((_) async => fail('must not invoke iOS notifications'));
    expect(
      await notifications.sync(const CoupleSpace(coupleId: 'ab')),
      'unsupported',
    );
    await notifications.clear();
    expect(calls, isEmpty);
  });
}
