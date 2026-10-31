import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/album_repository.dart';

void main() {
  group('HttpAlbumRepository', () {
    test('listAlbums sends Bearer token and parses response', () async {
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.url.path, '/api/v1/albums');
        return http.Response(
          jsonEncode([
            {
              'id': 'album-1',
              'coupleId': 'couple-1',
              'title': 'Kỷ niệm Đà Lạt',
              'description': 'Mùa thu 2026',
              'coverPhotoId': 'photo-1',
              'coverPhotoPath': '/api/v1/photos/photo-1/image',
              'photoCount': 5,
              'createdBy': 'user-1',
              'createdAt': '2026-10-30T10:00:00Z',
              'updatedAt': '2026-10-30T12:00:00Z',
            }
          ]),
          200,
        );
      });

      final repo = HttpAlbumRepository(baseUrl: 'http://localhost:8080', client: client);
      final albums = await repo.listAlbums('test-token');

      expect(albums.length, 1);
      expect(albums.first.id, 'album-1');
      expect(albums.first.title, 'Kỷ niệm Đà Lạt');
      expect(albums.first.photoCount, 5);
    });

    test('createAlbum sends JSON body and returns AlbumSummary', () async {
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.headers['Content-Type'], 'application/json');
        expect(request.url.path, '/api/v1/albums');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['title'], 'Album mới');

        return http.Response(
          jsonEncode({
            'id': 'album-new',
            'coupleId': 'couple-1',
            'title': 'Album mới',
            'description': null,
            'coverPhotoId': null,
            'coverPhotoPath': null,
            'photoCount': 0,
            'createdBy': 'user-1',
            'createdAt': '2026-10-31T10:00:00Z',
            'updatedAt': '2026-10-31T10:00:00Z',
          }),
          201,
        );
      });

      final repo = HttpAlbumRepository(baseUrl: 'http://localhost:8080', client: client);
      final album = await repo.createAlbum('test-token', 'Album mới');

      expect(album.id, 'album-new');
      expect(album.title, 'Album mới');
      expect(album.photoCount, 0);
    });

    test('addPhotoToAlbum sends PUT and returns updated AlbumSummary', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/albums/album-1/photos/photo-99');
        return http.Response(
          jsonEncode({
            'id': 'album-1',
            'coupleId': 'couple-1',
            'title': 'Album 1',
            'description': null,
            'coverPhotoId': 'photo-99',
            'coverPhotoPath': '/api/v1/photos/photo-99/image',
            'photoCount': 1,
            'createdBy': 'user-1',
            'createdAt': '2026-10-31T10:00:00Z',
            'updatedAt': '2026-10-31T10:00:00Z',
          }),
          200,
        );
      });

      final repo = HttpAlbumRepository(baseUrl: 'http://localhost:8080', client: client);
      final updated = await repo.addPhotoToAlbum('test-token', 'album-1', 'photo-99');

      expect(updated.photoCount, 1);
      expect(updated.coverPhotoId, 'photo-99');
    });

    test('403 forbidden throws readable AlbumException', () async {
      final client = MockClient((_) async => http.Response('', 403));
      final repo = HttpAlbumRepository(baseUrl: 'http://localhost:8080', client: client);

      expect(
        () => repo.listAlbums('test-token'),
        throwsA(isA<AlbumException>().having(
          (e) => e.message,
          'message',
          contains('ghép đôi'),
        )),
      );
    });
  });

  group('MockAlbumRepository', () {
    test('creates album, adds and removes photo in memory', () async {
      final mock = MockAlbumRepository();
      expect(await mock.listAlbums('token'), isEmpty);

      final created = await mock.createAlbum('token', 'Test Album', description: 'Desc');
      expect(created.title, 'Test Album');
      expect(created.photoCount, 0);

      var list = await mock.listAlbums('token');
      expect(list.length, 1);

      final withPhoto = await mock.addPhotoToAlbum('token', created.id, 'photo-1');
      expect(withPhoto.photoCount, 1);
      expect(withPhoto.coverPhotoId, 'photo-1');

      final detail = await mock.getAlbumDetail('token', created.id);
      expect(detail.photos.length, 1);
      expect(detail.photos.first.id, 'photo-1');

      final withoutPhoto = await mock.removePhotoFromAlbum('token', created.id, 'photo-1');
      expect(withoutPhoto.photoCount, 0);
      expect(withoutPhoto.coverPhotoId, isNull);

      await mock.deleteAlbum('token', created.id);
      list = await mock.listAlbums('token');
      expect(list, isEmpty);
    });
  });
}
