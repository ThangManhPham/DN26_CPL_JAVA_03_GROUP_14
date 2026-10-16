import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_exception.dart';
import 'package:mobile/core/network/dio_client.dart';
import 'package:mobile/core/storage/secure_storage.dart';
import 'package:mobile/features/auth/data/http_auth_repository.dart';

void main() {
  test('HttpAuthRepository follows register, login and profile contract', () async {
    final previousOverride = HttpOverrides.current;
    HttpOverrides.global = null;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      HttpOverrides.global = previousOverride;
    });

    final seen = <String>[];
    server.listen((request) async {
      final path = '${request.method} ${request.uri.path}';
      seen.add(path);
      final body = await utf8.decoder.bind(request).join();
      final response = request.response;
      response.headers.contentType = ContentType.json;
      switch (path) {
        case 'POST /api/v1/auth/register':
          expect(jsonDecode(body), {
            'email': 'alex@example.com',
            'password': 'Password123!',
            'displayName': 'Alex',
          });
          response.statusCode = 201;
          response.write(
            '{"id":"u1","email":"alex@example.com","displayName":"Alex"}',
          );
        case 'POST /api/v1/auth/login':
          response
            ..write(
              '{"accessToken":"token-1","tokenType":"Bearer",'
              '"user":{"id":"u1","email":"alex@example.com","displayName":"Alex"}}',
            )
            ..close();
          return;
        case 'GET /api/v1/users/me':
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer token-1',
          );
          response.write(
            '{"id":"u1","email":"alex@example.com","displayName":"Alex"}',
          );
        case 'PATCH /api/v1/users/me':
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer token-1',
          );
          expect(jsonDecode(body), {'displayName': 'Sam'});
          response.write(
            '{"id":"u1","email":"alex@example.com","displayName":"Sam"}',
          );
        default:
          response.statusCode = 404;
          response.write('{"code":"NOT_FOUND"}');
      }
      await response.close();
    });

    final storage = SecureStorageService();
    final dioClient = DioClient(
      baseUrl: 'http://127.0.0.1:${server.port}',
      storage: storage,
    );
    final repository = HttpAuthRepository(
      client: dioClient,
      storage: storage,
    );
    final session = await repository.register(
      'alex@example.com',
      'Password123!',
      'Alex',
    );
    expect(session.token, 'token-1');
    expect((await repository.getProfile(session.token)).displayName, 'Alex');
    expect(seen, [
      'POST /api/v1/auth/register',
      'POST /api/v1/auth/login',
      'GET /api/v1/users/me',
    ]);
  });

  test('SecureStorageService saves and retrieves token', () async {
    final storage = SecureStorageService();
    await storage.saveToken('test-token-123');
    expect(await storage.getToken(), 'test-token-123');
    expect(await storage.hasToken(), true);
    await storage.deleteToken();
    expect(await storage.getToken(), null);
    expect(await storage.hasToken(), false);
  });

  test('AppException.fromJson parses error response correctly', () {
    final json = {
      'code': 'INVITE_EXPIRED',
      'message': 'Mã ghép đôi đã hết hạn.',
      'details': {'field': 'inviteCode'},
      'requestId': 'req_abc123',
    };
    final exception = AppException.fromJson(json);
    expect(exception.code, 'INVITE_EXPIRED');
    expect(exception.message, 'Mã ghép đôi đã hết hạn.');
    expect(exception.requestId, 'req_abc123');
  });
}
