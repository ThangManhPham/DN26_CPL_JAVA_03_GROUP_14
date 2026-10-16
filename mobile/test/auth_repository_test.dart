import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/auth_repository.dart';

void main() {
  test('HTTP auth client follows register, login and profile contract', () async {
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
          response.write(
            '{"accessToken":"token-1","tokenType":"Bearer",'
            '"user":{"id":"u1","email":"alex@example.com","displayName":"Alex"}}',
          );
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

    final repository = HttpAuthRepository(
      baseUrl: 'http://127.0.0.1:${server.port}',
    );
    final session = await repository.register(
      'alex@example.com',
      'Password123!',
      'Alex',
    );
    expect(session.token, 'token-1');
    expect((await repository.getProfile(session.token)).displayName, 'Alex');
    expect(
      (await repository.updateProfile(session.token, 'Sam')).displayName,
      'Sam',
    );
    expect(seen, [
      'POST /api/v1/auth/register',
      'POST /api/v1/auth/login',
      'GET /api/v1/users/me',
      'PATCH /api/v1/users/me',
    ]);
  });
}
