import 'dart:convert';

import 'package:dio/dio.dart';

/// Lỗi API đã chuẩn hóa theo contract tại `docs/05-api-contract.md`:
/// `{ code, message, details, requestId }`.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details = const <String, dynamic>{},
    this.requestId = '',
  });

  /// HTTP status; `0` nghĩa là không kết nối được tới server.
  final int statusCode;
  final String code;
  final String message;
  final Map<String, dynamic> details;
  final String requestId;

  /// Thông điệp tiếng Việt hiển thị cho người dùng. Một số module backend
  /// (auth) trả `message` tiếng Anh nên lỗi nghiệp vụ được map theo `code`;
  /// các trường hợp khác (pairing) dùng luôn `message` của server.
  String get userMessage => _localizedMessages[code] ?? message;

  static const Map<String, String> _localizedMessages = {
    'NETWORK_ERROR': 'Không thể kết nối máy chủ. Kiểm tra mạng rồi thử lại.',
    'EMAIL_ALREADY_EXISTS': 'Email này đã được sử dụng.',
    'INVALID_CREDENTIALS': 'Email hoặc mật khẩu không đúng.',
    'UNAUTHORIZED': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    'FORBIDDEN': 'Bạn không có quyền xem nội dung này.',
    'VALIDATION_ERROR': 'Thông tin chưa hợp lệ. Vui lòng kiểm tra lại.',
    'INVALID_INVITE_CODE': 'Mã ghép đôi không đúng hoặc đã được sử dụng.',
    'INVITE_EXPIRED': 'Mã ghép đôi đã hết hạn.',
    'CANNOT_PAIR_SELF': 'Không thể tự ghép đôi với chính mình.',
    'ALREADY_PAIRED': 'Bạn đã ghép đôi với một người khác rồi.',
    'INVITER_ALREADY_PAIRED': 'Người gửi mã đã thuộc về một cặp đôi khác.',
    'COUPLE_NOT_FOUND': 'Bạn chưa ghép đôi với ai.',
    'UNPAIRING_POLICY_PENDING':
        'Tính năng hủy ghép đôi đang tạm dừng để chốt chính sách dữ liệu (OD-03).',
    'PHOTO_NOT_FOUND': 'Không tìm thấy ảnh.',
    'COUPLE_REQUIRED': 'Bạn cần ghép đôi trước khi dùng tính năng này.',
    'EVENT_NOT_FOUND': 'Sự kiện không còn tồn tại hoặc bạn không có quyền xem.',
    'EVENT_CONFLICT':
        'Người ấy đã thay đổi sự kiện. Tải bản mới trước khi sửa tiếp.',
  };

  bool get isNetworkFailure => statusCode == 0;
  bool get isUnauthenticated => statusCode == 401;

  /// 401 do token hết hạn/không hợp lệ. `INVALID_CREDENTIALS` là sai mật khẩu
  /// khi đăng nhập, không phải phiên hết hạn.
  bool get isSessionExpired =>
      statusCode == 401 && code != 'INVALID_CREDENTIALS';
  bool get isForbidden => statusCode == 403 || code == 'FORBIDDEN';
  bool get isNotFound => statusCode == 404 || code == 'COUPLE_NOT_FOUND';
  bool get isConflict => statusCode == 409;

  /// Dựng lỗi từ `DioException`, ưu tiên `message` do backend trả về
  /// (backend đã trả tiếng Việt) và chỉ fallback khi body không hợp lệ.
  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    if (response == null) {
      return const ApiException(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: 'Không thể kết nối máy chủ. Kiểm tra mạng rồi thử lại.',
      );
    }
    final status = response.statusCode ?? 0;
    final body = _decodeBody(response.data);
    final serverMessage = body['message'];
    return ApiException(
      statusCode: status,
      code: body['code'] as String? ?? 'HTTP_$status',
      message:
          (serverMessage is String && serverMessage.isNotEmpty && status < 500)
          ? serverMessage
          : _fallbackMessage(status),
      details: _asMap(body['details']),
      requestId: body['requestId'] as String? ?? '',
    );
  }

  static Map<String, dynamic> _decodeBody(dynamic data) {
    if (data is Map) return _asMap(data);
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return _asMap(decoded);
      } on FormatException {
        // Body không phải JSON (ví dụ trang HTML của proxy) -> dùng fallback.
      }
    }
    return const <String, dynamic>{};
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, dynamic>{};
  }

  static String _fallbackMessage(int status) {
    switch (status) {
      case 400:
        return 'Yêu cầu chưa hợp lệ. Vui lòng kiểm tra lại.';
      case 401:
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      case 403:
        return 'Bạn không có quyền xem nội dung này.';
      case 404:
        return 'Không tìm thấy nội dung bạn cần.';
      case 409:
        return 'Dữ liệu đã thay đổi. Vui lòng tải lại rồi thử lại.';
      case 413:
        return 'Dữ liệu gửi lên vượt quá giới hạn cho phép.';
      case 422:
        return 'Thông tin chưa hợp lệ. Vui lòng kiểm tra lại.';
      case 429:
        return 'Bạn thao tác quá nhanh. Vui lòng thử lại sau.';
      case 501:
        return 'Tính năng này chưa khả dụng.';
      default:
        return 'Máy chủ gặp lỗi. Vui lòng thử lại.';
    }
  }

  @override
  String toString() =>
      'ApiException($statusCode, $code, $message, requestId=$requestId)';
}
