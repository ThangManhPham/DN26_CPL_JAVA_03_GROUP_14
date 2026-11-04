import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/state/auth_controller.dart';
import 'package:mobile/core/storage/token_storage.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';

/// Hai tài khoản A/B giống `main.dart` khi chạy mock.
MockAuthRepository seededAuthRepository() {
  MockAuthRepository.clear();
  return MockAuthRepository(latency: Duration.zero)
    ..seed(
      email: 'alex@ourspace.dev',
      password: 'Password123!',
      displayName: 'Alex',
    )
    ..seed(
      email: 'sam@ourspace.dev',
      password: 'Password123!',
      displayName: 'Sam',
    );
}

void main() {
  test('login lưu token, tạo phiên và đồng bộ token sang HTTP client', () async {
    final storage = InMemoryTokenStorage();
    final tokens = <String?>[];
    final controller = AuthController(
      repository: seededAuthRepository(),
      storage: storage,
      onTokenChanged: tokens.add,
    );

    await controller.login('alex@ourspace.dev', 'Password123!');

    expect(controller.isAuthenticated, isTrue);
    expect(controller.user?.displayName, 'Alex');
    expect(await storage.read(), controller.token);
    expect(tokens.last, controller.token);
  });

  test('login sai mật khẩu ném lỗi theo contract và không tạo phiên', () async {
    final controller = AuthController(
      repository: seededAuthRepository(),
      storage: InMemoryTokenStorage(),
    );

    await expectLater(
      controller.login('alex@ourspace.dev', 'sai-mat-khau'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.userMessage,
          'userMessage',
          'Email hoặc mật khẩu không đúng.',
        ),
      ),
    );
    expect(controller.isAuthenticated, isFalse);
  });

  test('restore khôi phục phiên từ token đã lưu khi mở app', () async {
    final storage = InMemoryTokenStorage();
    // `MockAuthRepository` cấp token `mock-token-<userId>`; user A đầu tiên là
    // `mock-1`.
    await storage.write('mock-token-mock-1');
    final controller = AuthController(
      repository: seededAuthRepository(),
      storage: storage,
    );

    await controller.restore();

    expect(controller.isRestoring, isFalse);
    expect(controller.isAuthenticated, isTrue);
    expect(controller.user?.displayName, 'Alex');
  });

  test('restore xóa phiên khi token không còn hợp lệ', () async {
    final storage = InMemoryTokenStorage();
    await storage.write('token-khong-hop-le');
    final controller = AuthController(
      repository: seededAuthRepository(),
      storage: storage,
    );

    await controller.restore();

    expect(controller.isAuthenticated, isFalse);
    expect(await storage.read(), isNull);
  });

  test('forceLogout (khi interceptor nhận 401) xóa phiên và token', () async {
    final storage = InMemoryTokenStorage();
    final tokens = <String?>[];
    final controller = AuthController(
      repository: seededAuthRepository(),
      storage: storage,
      onTokenChanged: tokens.add,
    );
    await controller.login('alex@ourspace.dev', 'Password123!');

    controller.forceLogout();

    expect(controller.isAuthenticated, isFalse);
    expect(tokens.last, isNull);
    expect(await storage.read(), isNull);
  });
}
