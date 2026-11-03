import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/mock_web_sync.dart';
import 'timeline_models.dart';

/// Contract timeline & reaction (docs/05-api-contract.md §5.3).
abstract class TimelineRepository {
  /// `GET /api/v1/photos?cursor=&limit=`
  Future<PhotoPage> fetchPage({String? cursor, int limit});

  /// `GET /api/v1/photos/{id}`
  Future<PhotoItem> fetchPhoto(String id);

  /// `PUT /api/v1/photos/{id}/reaction` — thay reaction hiện hành của mình.
  Future<void> setReaction(String photoId, PhotoReactionType type);

  /// `DELETE /api/v1/photos/{id}/reaction`
  Future<void> clearReaction(String photoId);

  /// Tải nội dung ảnh qua endpoint có xác thực (`imagePath`).
  /// Không dùng URL công khai để tránh lưu vĩnh viễn link riêng tư.
  Future<Uint8List> fetchImage(String imagePath);
}

class ApiTimelineRepository implements TimelineRepository {
  ApiTimelineRepository(this._client);

  final ApiClient _client;

  @override
  Future<PhotoPage> fetchPage({String? cursor, int limit = 20}) async =>
      PhotoPage.fromJson(
        await _client.getJson(
          '/api/v1/photos',
          query: {'limit': limit, 'cursor': ?cursor},
        ),
      );

  @override
  Future<PhotoItem> fetchPhoto(String id) async =>
      PhotoItem.fromJson(await _client.getJson('/api/v1/photos/$id'));

  @override
  Future<void> setReaction(String photoId, PhotoReactionType type) async {
    await _client.putJson(
      '/api/v1/photos/$photoId/reaction',
      body: {'type': type.wire},
    );
  }

  @override
  Future<void> clearReaction(String photoId) async {
    await _client.deleteJson('/api/v1/photos/$photoId/reaction');
  }

  @override
  Future<Uint8List> fetchImage(String imagePath) =>
      _client.getBytes(imagePath);
}

/// Kịch bản lỗi để test/demo: danh sách rỗng, 403, 404.
enum MockTimelineScenario { success, empty, forbidden, notFound }

/// Mock theo đúng JSON shape của contract (camelCase), có độ trễ, nhiều trang
/// dữ liệu và các case lỗi.
class MockTimelineRepository implements TimelineRepository {
  MockTimelineRepository({
    this.photoCount = 23,
    this.latency = const Duration(milliseconds: 300),
    this.scenario = MockTimelineScenario.success,
    this.failOnPageCall,
    this.failReaction = false,
    String Function()? currentUserId,
  }) : _currentUserId = currentUserId ?? (() => 'mock-me') {
    _load();
    if (_photos.isEmpty && photoCount > 0) {
      _seed(photoCount);
    }
  }

  /// Tổng số ảnh giả; đặt 0 để mô phỏng danh sách rỗng.
  final int photoCount;
  final Duration latency;
  MockTimelineScenario scenario;

  /// Lần gọi `fetchPage` thứ N (1-based) sẽ lỗi — dùng để test nút thử lại.
  int? failOnPageCall;

  /// `true` để mô phỏng reaction thất bại (test rollback optimistic update).
  bool failReaction;

  final String Function() _currentUserId;
  int _pageCalls = 0;

  /// Dùng static để chia sẻ dữ liệu giữa các instance trong cùng runtime.
  static final List<PhotoItem> _photos = [];
  static final Map<String, List<PhotoReaction>> _reactions = {};

  /// Bytes thật của ảnh vừa gửi, khoá theo `imagePath`.
  ///
  /// Không lưu được vào LocalStorage (quá lớn) nên chỉ tồn tại trong phiên chạy;
  /// ảnh không có bytes sẽ hiển thị placeholder.
  static final Map<String, Uint8List> _imageBytes = {};

  static void _save() {
    MockWebSync.save('mock_timeline', {
      'photos': _photos.map((p) => p.toJson()).toList(),
      'reactions': _reactions.map((k, v) => MapEntry(k, v.map((r) => {
            'userId': r.userId,
            'type': r.type.wire,
          }).toList())),
    });
  }

  static void _load() {
    final data = MockWebSync.load('mock_timeline');
    if (data is Map) {
      if (data['photos'] is List) {
        _photos.clear();
        _photos.addAll((data['photos'] as List)
            .map((p) => PhotoItem.fromJson(p as Map<String, dynamic>)));
      }
      if (data['reactions'] is Map) {
        _reactions.clear();
        final map = (data['reactions'] as Map).cast<String, dynamic>();
        map.forEach((k, v) {
          final list = v as List;
          _reactions[k] = list
              .map((r) => PhotoReaction(
                    userId: r['userId'] as String,
                    type: PhotoReactionType.fromWire(r['type'] as String)!,
                  ))
              .toList();
        });
      }
    }
  }

  /// Xóa toàn bộ dữ liệu mock (dùng cho test).
  static void clear() {
    _photos.clear();
    _reactions.clear();
    _imageBytes.clear();
    _save();
  }

  /// Thêm một ảnh mới (dùng cho MockPhotoRepository) và giữ luôn bytes của ảnh
  /// để timeline hiển thị được đúng nội dung vừa gửi.
  static void addPhoto(PhotoItem photo, {Uint8List? bytes}) {
    _load();
    _photos.removeWhere((item) => item.id == photo.id);
    _photos.insert(0, photo);
    if (bytes != null && bytes.isNotEmpty) _imageBytes[photo.imagePath] = bytes;
    _save();
  }

  void _seed(int count) {
    for (var i = 0; i < count; i++) {
      final id = 'mock-photo-${i + 1}';
      final fromPartner = i.isEven;
      _photos.add(PhotoItem(
        id: id,
        coupleId: 'mock-couple',
        senderId: fromPartner ? partnerId : _currentUserId(),
        senderDisplayName: fromPartner ? partnerName : 'Bạn',
        mimeType: 'image/png',
        sizeBytes: _photoSizeBytes,
        createdAt: seedBaseUtc.subtract(Duration(hours: i * 7)),
        imagePath: '/api/v1/photos/$id/image',
        reactions: _reactions[id] ?? const [],
      ));
    }
    _save();
  }

  /// Thời điểm gửi của ảnh mock mới nhất (ảnh thứ i lùi thêm i*7 giờ).
  static final DateTime seedBaseUtc = DateTime.utc(2026, 10, 25, 9);

  static const String partnerId = 'mock-partner';
  static const String partnerName = 'Người ấy';
  static const int _photoSizeBytes = 42 * 1024;

  /// Ảnh 1x1 PNG hợp lệ để widget test giải mã được mà không cần mạng.
  static final Uint8List _placeholderPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  );

  @override
  Future<PhotoPage> fetchPage({String? cursor, int limit = 20}) async {
    _load();
    await Future<void>.delayed(latency);
    _pageCalls++;
    if (failOnPageCall == _pageCalls) {
      throw const ApiException(
        statusCode: 500,
        code: 'INTERNAL_ERROR',
        message: 'Mock: không tải được trang dữ liệu.',
      );
    }
    _throwScenarioError();
    if (_photos.isEmpty) {
      return const PhotoPage(items: [], nextCursor: null);
    }
    final offset = int.tryParse(cursor ?? '0') ?? 0;
    final end = math.min(offset + limit, _photos.length);
    
    // Cập nhật reaction và tên hiển thị cho ảnh từ map static
    final me = _currentUserId();
    final items = _photos.sublist(offset, end).map((p) {
      final isMe = p.senderId == me;
      return p.copyWith(
        senderDisplayName: isMe ? 'Bạn' : (p.senderId == partnerId ? partnerName : p.senderDisplayName),
        reactions: _reactions[p.id] ?? const [],
      );
    }).toList();

    return PhotoPage(
      items: items,
      nextCursor: end < _photos.length ? '$end' : null,
    );
  }

  @override
  Future<PhotoItem> fetchPhoto(String id) async {
    _load();
    await Future<void>.delayed(latency);
    _throwScenarioError();
    final photo = _photos.cast<PhotoItem?>().firstWhere(
          (p) => p?.id == id,
          orElse: () => null,
        );
    if (photo == null) {
      throw const ApiException(
        statusCode: 404,
        code: 'PHOTO_NOT_FOUND',
        message: 'Không tìm thấy ảnh.',
      );
    }
    final me = _currentUserId();
    final isMe = photo.senderId == me;
    return photo.copyWith(
      senderDisplayName: isMe ? 'Bạn' : (photo.senderId == partnerId ? partnerName : photo.senderDisplayName),
      reactions: _reactions[id] ?? const [],
    );
  }

  @override
  Future<void> setReaction(String photoId, PhotoReactionType type) async {
    _load();
    await Future<void>.delayed(latency);
    _throwReactionError();
    final me = _currentUserId();
    _reactions[photoId] = [
      ...?_reactions[photoId]?.where((item) => item.userId != me),
      PhotoReaction(userId: me, type: type),
    ];
    _save();
  }

  @override
  Future<void> clearReaction(String photoId) async {
    _load();
    await Future<void>.delayed(latency);
    _throwReactionError();
    final me = _currentUserId();
    final remaining = _reactions[photoId]
        ?.where((item) => item.userId != me)
        .toList(growable: false);
    if (remaining == null || remaining.isEmpty) {
      _reactions.remove(photoId);
    } else {
      _reactions[photoId] = remaining;
    }
    _save();
  }

  @override
  Future<Uint8List> fetchImage(String imagePath) async {
    await Future<void>.delayed(latency);
    return _imageBytes[imagePath] ?? _placeholderPng;
  }

  void _throwScenarioError() {
    switch (scenario) {
      case MockTimelineScenario.success:
      case MockTimelineScenario.empty:
        return;
      case MockTimelineScenario.forbidden:
        throw const ApiException(
          statusCode: 403,
          code: 'FORBIDDEN',
          message: 'Bạn không có quyền xem nội dung này.',
        );
      case MockTimelineScenario.notFound:
        throw const ApiException(
          statusCode: 404,
          code: 'COUPLE_NOT_FOUND',
          message: 'Bạn chưa ghép đôi với ai.',
        );
    }
  }

  void _throwReactionError() {
    if (!failReaction) return;
    throw const ApiException(
      statusCode: 500,
      code: 'INTERNAL_ERROR',
      message: 'Mock: không lưu được reaction.',
    );
  }
}
