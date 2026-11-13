import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';

import '../support/fake_dio_adapter.dart';

void main() {
  late FakeDioAdapter adapter;

  ApiClient buildClient({
    Future<ResponseBody> Function(RequestOptions options)? handler,
  }) {
    adapter = FakeDioAdapter(
      handler ?? (options) async => jsonBody({'ok': true}, 200),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
      ..httpClientAdapter = adapter;
    return ApiClient(baseUrl: 'http://localhost:8080', dio: dio);
  }

  test('interceptor gắn "Authorization: Bearer <token>" khi có token', () async {
    final client = buildClient();
    client.token = 'token-1';

    await client.getJson('/api/v1/users/me');

    expect(adapter.requests.single.headers['Authorization'], 'Bearer token-1');
  });

  test('không ghi đè Authorization khi request đã có header riêng', () async {
    final client = buildClient();
    client.token = 'token-1';

    await client.getJson(
      '/api/v1/users/me',
      headers: ApiClient.bearer('token-2'),
    );

    expect(adapter.requests.single.headers['Authorization'], 'Bearer token-2');
  });

  test('401 báo onUnauthenticated và ném ApiException phiên hết hạn', () async {
    var unauthenticated = 0;
    final client = buildClient(
      handler: (options) async => jsonBody({
        'code': 'UNAUTHORIZED',
        'message': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        'requestId': 'req-401',
      }, 401),
    );
    client.onUnauthenticated = () => unauthenticated++;

    await expectLater(
      client.getJson('/api/v1/users/me'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.isSessionExpired,
          'isSessionExpired',
          isTrue,
        ),
      ),
    );
    expect(unauthenticated, 1);
  });

  test('lỗi được chuẩn hóa theo contract code/message/details/requestId', () async {
    final client = buildClient(
      handler: (options) async => jsonBody({
        'code': 'INVALID_INVITE_CODE',
        'message': 'Mã ghép đôi không tồn tại hoặc đã được sử dụng.',
        'details': {'inviteCode': 'K7P4R8'},
        'requestId': 'req-42',
      }, 400),
    );

    await expectLater(
      client.postJson('/api/v1/couples/join', body: {'inviteCode': 'K7P4R8'}),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 400)
            .having((error) => error.code, 'code', 'INVALID_INVITE_CODE')
            .having(
              (error) => error.details['inviteCode'],
              'details.inviteCode',
              'K7P4R8',
            )
            .having((error) => error.requestId, 'requestId', 'req-42'),
      ),
    );
  });

  test('mất kết nối -> NETWORK_ERROR với statusCode 0', () async {
    final client = buildClient(
      handler: (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );

    await expectLater(
      client.getJson('/api/v1/photos'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 0)
            .having((error) => error.code, 'code', 'NETWORK_ERROR')
            .having(
              (error) => error.isNetworkFailure,
              'isNetworkFailure',
              isTrue,
            ),
      ),
    );
  });
}
