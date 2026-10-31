import 'dart:convert';
import 'package:http/http.dart' as http;
import 'photo_repository.dart';

class AlbumSummary {
  const AlbumSummary({
    required this.id,
    required this.coupleId,
    required this.title,
    this.description,
    this.coverPhotoId,
    this.coverPhotoPath,
    required this.photoCount,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String coupleId;
  final String title;
  final String? description;
  final String? coverPhotoId;
  final String? coverPhotoPath;
  final int photoCount;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AlbumSummary.fromJson(Map<String, dynamic> json) => AlbumSummary(
        id: json['id'] as String,
        coupleId: json['coupleId'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        coverPhotoId: json['coverPhotoId'] as String?,
        coverPhotoPath: json['coverPhotoPath'] as String?,
        photoCount: (json['photoCount'] as num).toInt(),
        createdBy: json['createdBy'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class AlbumDetail {
  const AlbumDetail({
    required this.id,
    required this.coupleId,
    required this.title,
    this.description,
    this.coverPhotoId,
    this.coverPhotoPath,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.photos,
  });

  final String id;
  final String coupleId;
  final String title;
  final String? description;
  final String? coverPhotoId;
  final String? coverPhotoPath;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SharedPhoto> photos;

  factory AlbumDetail.fromJson(Map<String, dynamic> json) => AlbumDetail(
        id: json['id'] as String,
        coupleId: json['coupleId'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        coverPhotoId: json['coverPhotoId'] as String?,
        coverPhotoPath: json['coverPhotoPath'] as String?,
        createdBy: json['createdBy'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        photos: (json['photos'] as List<dynamic>)
            .map((p) => SharedPhoto.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}

class AlbumException implements Exception {
  const AlbumException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class AlbumRepository {
  Future<List<AlbumSummary>> listAlbums(String token);
  Future<AlbumSummary> createAlbum(String token, String title, {String? description, String? coverPhotoId});
  Future<AlbumDetail> getAlbumDetail(String token, String albumId);
  Future<AlbumSummary> addPhotoToAlbum(String token, String albumId, String photoId);
  Future<AlbumSummary> removePhotoFromAlbum(String token, String albumId, String photoId);
  Future<void> deleteAlbum(String token, String albumId);
  Future<List<SharedPhoto>> getAvailablePhotos(String token);
}

class HttpAlbumRepository implements AlbumRepository {
  HttpAlbumRepository({required String baseUrl, http.Client? client})
      : _base = Uri.parse(baseUrl),
        _client = client ?? http.Client();

  final Uri _base;
  final http.Client _client;

  @override
  Future<List<AlbumSummary>> listAlbums(String token) async {
    final response = await _client.get(
      _base.resolve('/api/v1/albums'),
      headers: _headers(token),
    );
    _check(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((json) => AlbumSummary.fromJson(json as Map<String, dynamic>)).toList();
  }

  @override
  Future<AlbumSummary> createAlbum(
    String token,
    String title, {
    String? description,
    String? coverPhotoId,
  }) async {
    final body = jsonEncode({
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      if (coverPhotoId != null) 'coverPhotoId': coverPhotoId,
    });
    final response = await _client.post(
      _base.resolve('/api/v1/albums'),
      headers: _headers(token)..['Content-Type'] = 'application/json',
      body: body,
    );
    _check(response);
    return AlbumSummary.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<AlbumDetail> getAlbumDetail(String token, String albumId) async {
    final response = await _client.get(
      _base.resolve('/api/v1/albums/$albumId'),
      headers: _headers(token),
    );
    _check(response);
    return AlbumDetail.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<AlbumSummary> addPhotoToAlbum(String token, String albumId, String photoId) async {
    final response = await _client.put(
      _base.resolve('/api/v1/albums/$albumId/photos/$photoId'),
      headers: _headers(token),
    );
    _check(response);
    return AlbumSummary.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<AlbumSummary> removePhotoFromAlbum(String token, String albumId, String photoId) async {
    final response = await _client.delete(
      _base.resolve('/api/v1/albums/$albumId/photos/$photoId'),
      headers: _headers(token),
    );
    _check(response);
    return AlbumSummary.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<void> deleteAlbum(String token, String albumId) async {
    final response = await _client.delete(
      _base.resolve('/api/v1/albums/$albumId'),
      headers: _headers(token),
    );
    _check(response);
  }

  @override
  Future<List<SharedPhoto>> getAvailablePhotos(String token) async {
    final response = await _client.get(
      _base.resolve('/api/v1/albums/available-photos'),
      headers: _headers(token),
    );
    _check(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((json) => SharedPhoto.fromJson(json as Map<String, dynamic>)).toList();
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
      };

  void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401) {
      throw const AlbumException('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }
    if (response.statusCode == 403) {
      throw const AlbumException('Bạn cần ghép đôi hoặc không có quyền truy cập album này.');
    }
    if (response.statusCode == 404) {
      throw const AlbumException('Album hoặc tài nguyên không tồn tại.');
    }
    if (response.statusCode == 422 || response.statusCode == 400) {
      try {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        final msg = err['message'] as String?;
        if (msg != null && msg.isNotEmpty) {
          throw AlbumException(msg);
        }
      } catch (e) {
        if (e is AlbumException) rethrow;
      }
      throw const AlbumException('Thông tin yêu cầu không hợp lệ.');
    }
    throw const AlbumException('Đã xảy ra lỗi khi kết nối máy chủ. Vui lòng thử lại.');
  }
}

class MockAlbumRepository implements AlbumRepository {
  final List<AlbumSummary> _albums = [];
  final Map<String, List<SharedPhoto>> _albumPhotos = {};
  final List<SharedPhoto> _availablePhotos = [];

  @override
  Future<List<AlbumSummary>> listAlbums(String token) async => List.unmodifiable(_albums);

  @override
  Future<AlbumSummary> createAlbum(
    String token,
    String title, {
    String? description,
    String? coverPhotoId,
  }) async {
    final id = 'mock-album-${_albums.length + 1}';
    final now = DateTime.now();
    final album = AlbumSummary(
      id: id,
      coupleId: 'mock-couple-1',
      title: title,
      description: description,
      coverPhotoId: coverPhotoId,
      coverPhotoPath: coverPhotoId != null ? '/api/v1/photos/$coverPhotoId/image' : null,
      photoCount: coverPhotoId != null ? 1 : 0,
      createdBy: 'mock-user-1',
      createdAt: now,
      updatedAt: now,
    );
    _albums.insert(0, album);
    _albumPhotos[id] = [];
    return album;
  }

  @override
  Future<AlbumDetail> getAlbumDetail(String token, String albumId) async {
    final album = _albums.firstWhere(
      (a) => a.id == albumId,
      orElse: () => throw const AlbumException('Album không tồn tại.'),
    );
    return AlbumDetail(
      id: album.id,
      coupleId: album.coupleId,
      title: album.title,
      description: album.description,
      coverPhotoId: album.coverPhotoId,
      coverPhotoPath: album.coverPhotoPath,
      createdBy: album.createdBy,
      createdAt: album.createdAt,
      updatedAt: album.updatedAt,
      photos: _albumPhotos[albumId] ?? [],
    );
  }

  @override
  Future<AlbumSummary> addPhotoToAlbum(String token, String albumId, String photoId) async {
    final index = _albums.indexWhere((a) => a.id == albumId);
    if (index == -1) throw const AlbumException('Album không tồn tại.');
    final existing = _albumPhotos[albumId] ?? [];
    if (!existing.any((p) => p.id == photoId)) {
      final photo = _availablePhotos.firstWhere(
        (p) => p.id == photoId,
        orElse: () => SharedPhoto(
          id: photoId,
          senderId: 'mock-user-1',
          createdAt: DateTime.now(),
          imagePath: '/api/v1/photos/$photoId/image',
        ),
      );
      existing.insert(0, photo);
      _albumPhotos[albumId] = existing;
    }
    final old = _albums[index];
    final updated = AlbumSummary(
      id: old.id,
      coupleId: old.coupleId,
      title: old.title,
      description: old.description,
      coverPhotoId: old.coverPhotoId ?? photoId,
      coverPhotoPath: old.coverPhotoPath ?? '/api/v1/photos/$photoId/image',
      photoCount: existing.length,
      createdBy: old.createdBy,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
    );
    _albums[index] = updated;
    return updated;
  }

  @override
  Future<AlbumSummary> removePhotoFromAlbum(String token, String albumId, String photoId) async {
    final index = _albums.indexWhere((a) => a.id == albumId);
    if (index == -1) throw const AlbumException('Album không tồn tại.');
    final existing = _albumPhotos[albumId] ?? [];
    existing.removeWhere((p) => p.id == photoId);
    _albumPhotos[albumId] = existing;

    final old = _albums[index];
    final nextCover = existing.isEmpty ? null : existing.first.id;
    final updated = AlbumSummary(
      id: old.id,
      coupleId: old.coupleId,
      title: old.title,
      description: old.description,
      coverPhotoId: nextCover,
      coverPhotoPath: nextCover != null ? '/api/v1/photos/$nextCover/image' : null,
      photoCount: existing.length,
      createdBy: old.createdBy,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
    );
    _albums[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteAlbum(String token, String albumId) async {
    _albums.removeWhere((a) => a.id == albumId);
    _albumPhotos.remove(albumId);
  }

  @override
  Future<List<SharedPhoto>> getAvailablePhotos(String token) async =>
      List.unmodifiable(_availablePhotos);

  void seedMockPhoto(SharedPhoto photo) {
    _availablePhotos.add(photo);
  }
}
