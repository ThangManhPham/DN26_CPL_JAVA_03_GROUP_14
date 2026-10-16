/// Lỗi chuẩn hóa từ backend.
///
/// Backend trả về JSON dạng:
/// {
///   "code": "INVITE_EXPIRED",
///   "message": "Mã ghép đôi đã hết hạn.",
///   "details": {},
///   "requestId": "req_123"
/// }
class AppException implements Exception {
  const AppException({
    required this.message,
    this.code,
    this.requestId,
    this.details,
  });

  /// Tin nhắn thân thiện cho người dùng.
  final String message;

  /// Mã lỗi từ backend (ví dụ: INVITE_EXPIRED, INVITE_CODE_USED).
  final String? code;

  /// Request ID dùng debug.
  final String? requestId;

  /// Thông tin bổ sung từ server.
  final Map<String, dynamic>? details;

  factory AppException.fromJson(Map<String, dynamic> json) {
    return AppException(
      message: (json['message'] as String?) ?? 'Đã xảy ra lỗi không xác định.',
      code: json['code'] as String?,
      requestId: json['requestId'] as String?,
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => 'AppException($code): $message';
}

/// Marker interface cho các lỗi liên quan đến ghép đôi.
abstract class PairingException extends AppException {
  const PairingException({required super.message, super.code});
}

class InviteExpiredException extends PairingException {
  const InviteExpiredException() : super(message: 'Mã mời đã hết hạn.');
}

class InviteCodeUsedException extends PairingException {
  const InviteCodeUsedException() : super(message: 'Mã mời đã được sử dụng.');
}

class InviteCodeInvalidException extends PairingException {
  const InviteCodeInvalidException() : super(message: 'Mã mời không hợp lệ.');
}

class SelfPairingException extends PairingException {
  const SelfPairingException()
      : super(message: 'Bạn không thể ghép đôi với chính mình.');
}

class AlreadyCoupledException extends PairingException {
  const AlreadyCoupledException()
      : super(message: 'Tài khoản đã thuộc một cặp đôi khác.');
}

class UnauthenticatedException extends AppException {
  const UnauthenticatedException()
      : super(message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
}

class NetworkException extends AppException {
  const NetworkException()
      : super(message: 'Không thể kết nối máy chủ. Kiểm tra mạng rồi thử lại.');
}
