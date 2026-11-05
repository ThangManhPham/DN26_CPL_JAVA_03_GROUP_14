import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class SharedPhoto {
  const SharedPhoto({
    required this.id,
    required this.senderId,
    required this.createdAt,
    required this.imagePath,
  });
  final String id;
  final String senderId;
  final DateTime createdAt;
  final String imagePath;

  factory SharedPhoto.fromJson(Map<String, dynamic> json) => SharedPhoto(
    id: json['id'] as String,
    senderId: json['senderId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    imagePath: json['imagePath'] as String,
  );
}

class PhotoException implements Exception {
  const PhotoException(this.message);
  final String message;
}

abstract class PhotoRepository {
  Future<SharedPhoto?> latest(String token);
  Future<Uint8List> image(String token, SharedPhoto photo);
  Future<SharedPhoto> upload(
    String token,
    Uint8List bytes,
    String mimeType,
    String requestId,
  );
}

class HttpPhotoRepository implements PhotoRepository {
  HttpPhotoRepository({required String baseUrl, http.Client? client})
    : _base = Uri.parse(baseUrl),
      _client = client ?? http.Client();
  final Uri _base;
  final http.Client _client;

  @override
  Future<SharedPhoto?> latest(String token) async {
    final response = await _client.get(
      _base.resolve('/api/v1/photos/latest'),
      headers: _headers(token),
    );
    if (response.statusCode == 404) return null;
    _check(response);
    return SharedPhoto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<Uint8List> image(String token, SharedPhoto photo) async {
    final response = await _client.get(
      _base.resolve(photo.imagePath),
      headers: _headers(token),
    );
    _check(response);
    return response.bodyBytes;
  }

  @override
  Future<SharedPhoto> upload(
    String token,
    Uint8List bytes,
    String mimeType,
    String requestId,
  ) async {
    final request =
        http.MultipartRequest('POST', _base.resolve('/api/v1/photos'))
          ..headers.addAll(_headers(token))
          ..headers['Idempotency-Key'] = requestId
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: mimeType == 'image/png' ? 'photo.png' : 'photo.jpg',
              contentType: MediaType.parse(mimeType),
            ),
          );
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    _check(response);
    return SharedPhoto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
  };

  void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401) {
      throw const PhotoException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
    if (response.statusCode == 409) {
      throw const PhotoException('Bạn cần ghép đôi trước khi gửi ảnh.');
    }
    if (response.statusCode == 413) {
      throw const PhotoException('Ảnh quá lớn (tối đa 10 MB).');
    }
    if (response.statusCode == 400) {
      throw const PhotoException(
        'Ảnh không hợp lệ. Chỉ hỗ trợ JPEG hoặc PNG, tối đa 10 MB.',
      );
    }
    throw const PhotoException('Không thể tải ảnh. Vui lòng thử lại.');
  }
}

String newPhotoRequestId() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class MockPhotoRepository implements PhotoRepository {
  SharedPhoto? _photo;
  Uint8List? _bytes;
  @override
  Future<SharedPhoto?> latest(String token) async => _photo;
  @override
  Future<Uint8List> image(String token, SharedPhoto photo) async =>
      _bytes ?? Uint8List(0);
  @override
  Future<SharedPhoto> upload(
    String token,
    Uint8List bytes,
    String mimeType,
    String requestId,
  ) async {
    _bytes = bytes;
    return _photo = SharedPhoto(
      id: requestId,
      senderId: 'mock',
      createdAt: DateTime.now(),
      imagePath: 'mock',
    );
  }
}
