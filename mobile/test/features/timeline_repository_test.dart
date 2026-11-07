import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/timeline/data/timeline_models.dart';
import 'package:mobile/features/timeline/data/timeline_repository.dart';

import '../support/fake_dio_adapter.dart';

void main() {
  late FakeDioAdapter adapter;
  late ApiTimelineRepository repository;

  void buildRepository(Future<ResponseBody> Function(RequestOptions) handler) {
    adapter = FakeDioAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
      ..httpClientAdapter = adapter;
    repository = ApiTimelineRepository(
      ApiClient(baseUrl: 'http://localhost:8080', dio: dio),
    );
  }

  test('fetchPage gửi cursor/limit và đọc JSON camelCase của contract', () async {
    buildRepository(
      (options) async => jsonBody({
        'items': [
          {
            'id': 'p1',
            'coupleId': 'c1',
            'senderId': 'u2',
            'senderDisplayName': 'Người ấy',
            'mimeType': 'image/png',
            'sizeBytes': 1024,
            'createdAt': '2026-10-21T09:00:00Z',
            'imagePath': '/api/v1/photos/p1/image',
            'reactions': [
              {'userId': 'u1', 'type': 'LOVE'},
            ],
          },
        ],
        'nextCursor': '20',
      }, 200),
    );

    final page = await repository.fetchPage(cursor: '10', limit: 20);

    expect(adapter.requests.single.path, '/api/v1/photos');
    expect(adapter.requests.single.queryParameters, {
      'limit': 20,
      'cursor': '10',
    });
    expect(page.nextCursor, '20');
    final photo = page.items.single;
    expect(photo.senderDisplayName, 'Người ấy');
    expect(photo.createdAt, DateTime.utc(2026, 10, 21, 9));
    expect(photo.imagePath, '/api/v1/photos/p1/image');
    expect(photo.reactionBy('u1'), PhotoReactionType.love);
  });

  test('setReaction gửi PUT với body wire đúng enum', () async {
    buildRepository((options) async => jsonBody({'ok': true}, 200));

    await repository.setReaction('p1', PhotoReactionType.laugh);

    final request = adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.path, '/api/v1/photos/p1/reaction');
    expect(request.data, {'type': 'LAUGH'});
  });

  test('clearReaction gửi DELETE tới endpoint reaction', () async {
    buildRepository((options) async => jsonBody({'ok': true}, 200));

    await repository.clearReaction('p1');

    final request = adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '/api/v1/photos/p1/reaction');
  });

  test('fetchPhoto đọc chi tiết ảnh và bỏ qua reaction có type lạ', () async {
    buildRepository(
      (options) async => jsonBody({
        'id': 'p9',
        'coupleId': 'c1',
        'senderId': 'u1',
        'sender': {'displayName': 'Alex'},
        'mimeType': 'image/jpeg',
        'sizeBytes': 2048,
        'createdAt': '2026-10-22T09:00:00Z',
        'imagePath': '/api/v1/photos/p9/image',
        'reactions': [
          {'userId': 'u2', 'type': 'UNKNOWN_TYPE'},
          {'userId': 'u1', 'type': 'SAD'},
        ],
      }, 200),
    );

    final photo = await repository.fetchPhoto('p9');

    expect(photo.senderDisplayName, 'Alex');
    expect(photo.reactions.length, 1);
    expect(photo.reactionBy('u1'), PhotoReactionType.sad);
  });

  test('fetchImage tải bytes qua endpoint có xác thực (không dùng URL công khai)', () async {
    buildRepository((options) async => bytesBody([1, 2, 3], 200));

    final bytes = await repository.fetchImage('/api/v1/photos/p1/image');

    expect(bytes, [1, 2, 3]);
    expect(adapter.requests.single.path, '/api/v1/photos/p1/image');
  });
}
