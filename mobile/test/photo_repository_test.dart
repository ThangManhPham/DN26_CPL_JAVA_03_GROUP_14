import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/photo_repository.dart';

void main() {
  test('photo request IDs are unique UUIDs', () {
    final first = newPhotoRequestId();
    final second = newPhotoRequestId();
    expect(first, isNot(second));
    expect(
      first,
      matches(RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$')),
    );
  });

  test('latest photo and image use Bearer auth without public URL', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer token-1');
      if (request.url.path == '/api/v1/photos/latest') {
        return http.Response(
          jsonEncode({
            'id': 'photo-1',
            'senderId': 'user-1',
            'createdAt': '2026-10-29T12:00:00Z',
            'imagePath': '/api/v1/photos/photo-1/image',
          }),
          200,
        );
      }
      expect(request.url.path, '/api/v1/photos/photo-1/image');
      return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
    });
    final repository = HttpPhotoRepository(
      baseUrl: 'http://localhost:8080',
      client: client,
    );
    final photo = await repository.latest('token-1');
    expect(photo?.id, 'photo-1');
    expect(await repository.image('token-1', photo!), [1, 2, 3]);
  });

  test('404 latest means empty state', () async {
    final repository = HttpPhotoRepository(
      baseUrl: 'http://localhost:8080',
      client: MockClient((_) async => http.Response('', 404)),
    );
    expect(await repository.latest('token'), isNull);
  });
}
