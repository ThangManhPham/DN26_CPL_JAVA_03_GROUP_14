import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
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
  }) : _currentUserId = currentUserId ?? (() => 'mock-me');

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

  /// Dùng static để chia sẻ reaction giữa các instance trong cùng runtime.
  static final Map<String, List<PhotoReaction>> _reactions = {};

  /// Xóa toàn bộ dữ liệu mock (dùng cho test).
  static void clear() {
    _reactions.clear();
  }

  static const String partnerId = 'mock-partner';
  static const String partnerName = 'Người ấy';
  static const int _photoSizeBytes = 42 * 1024;

  /// Ảnh 1x1 PNG hợp lệ để widget test giải mã được mà không cần mạng.
  static final Uint8List _placeholderPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  );

  @override
  Future<PhotoPage> fetchPage({String? cursor, int limit = 20}) async {
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
    if (photoCount == 0) {
      return const PhotoPage(items: [], nextCursor: null);
    }
    final offset = int.tryParse(cursor ?? '0') ?? 0;
    final end = math.min(offset + limit, photoCount);
    return PhotoPage(
      items: [
        for (var index = offset; index < end; index++) _photoAt(index),
      ],
      nextCursor: end < photoCount ? '$end' : null,
    );
  }

  @override
  Future<PhotoItem> fetchPhoto(String id) async {
    await Future<void>.delayed(latency);
    _throwScenarioError();
    final index = _indexOf(id);
    if (index < 0 || index >= photoCount) {
      throw const ApiException(
        statusCode: 404,
        code: 'PHOTO_NOT_FOUND',
        message: 'Không tìm thấy ảnh.',
      );
    }
    return _photoAt(index);
  }

  @override
  Future<void> setReaction(String photoId, PhotoReactionType type) async {
    await Future<void>.delayed(latency);
    _throwReactionError();
    final me = _currentUserId();
    _reactions[photoId] = [
      ...?_reactions[photoId]?.where((item) => item.userId != me),
      PhotoReaction(userId: me, type: type),
    ];
  }

  @override
  Future<void> clearReaction(String photoId) async {
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
  }

  @override
  Future<Uint8List> fetchImage(String imagePath) async {
    await Future<void>.delayed(latency);
    return _placeholderPng;
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

  PhotoItem _photoAt(int index) {
    final id = 'mock-photo-${index + 1}';
    final fromPartner = index.isEven;
    final senderId = fromPartner ? partnerId : _currentUserId();
    return PhotoItem(
      id: id,
      coupleId: 'mock-couple',
      senderId: senderId,
      senderDisplayName: fromPartner ? partnerName : 'Bạn',
      mimeType: 'image/png',
      sizeBytes: _photoSizeBytes,
      createdAt: DateTime.utc(
        2026,
        10,
        21,
        9,
      ).subtract(Duration(hours: index * 7)),
      imagePath: '/api/v1/photos/$id/image',
      reactions: _reactions[id] ?? const [],
    );
  }

  static int _indexOf(String id) =>
      int.tryParse(id.replaceFirst('mock-photo-', '')) == null
      ? -1
      : int.parse(id.replaceFirst('mock-photo-', '')) - 1;
}
