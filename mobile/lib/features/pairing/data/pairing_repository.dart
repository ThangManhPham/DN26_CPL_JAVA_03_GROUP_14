import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/mock_web_sync.dart';
import '../../auth/data/auth_models.dart';
import 'pairing_models.dart';

/// Contract pairing (docs/05-api-contract.md §5.2).
abstract class CoupleRepository {
  /// `POST /api/v1/couple-invites`
  Future<CoupleInvite> createInvite();

  /// `POST /api/v1/couples/join`
  Future<Couple> join(String inviteCode);

  /// `GET /api/v1/couples/me` — `null` khi chưa ghép đôi (404).
  Future<Couple?> current();

  /// `DELETE /api/v1/couples/me`
  Future<void> unpair();
}

class ApiCoupleRepository implements CoupleRepository {
  ApiCoupleRepository(this._client);

  final ApiClient _client;

  @override
  Future<CoupleInvite> createInvite() async =>
      CoupleInvite.fromJson(await _client.postJson('/api/v1/couple-invites'));

  @override
  Future<Couple> join(String inviteCode) async => Couple.fromJson(
    await _client.postJson(
      '/api/v1/couples/join',
      body: {'inviteCode': inviteCode},
    ),
  );

  @override
  Future<Couple?> current() async {
    try {
      return Couple.fromJson(await _client.getJson('/api/v1/couples/me'));
    } on ApiException catch (error) {
      if (error.isNotFound) return null;
      rethrow;
    }
  }

  @override
  Future<void> unpair() async {
    await _client.deleteJson('/api/v1/couples/me');
  }
}

/// Mock bám sát contract: có độ trễ và mô phỏng đủ case lỗi mã mời.
///
/// Mã đặc biệt để demo/test nhanh (đủ 6 ký tự thuộc bảng chữ hợp lệ nên nhập
/// được trực tiếp trên màn nhập mã):
/// - `EXPYR3` -> INVITE_EXPIRED
/// - `US3D22` -> INVALID_INVITE_CODE (mã đã dùng)
/// - `S3LF22` -> CANNOT_PAIR_SELF
/// - `PAYRD2` -> INVITER_ALREADY_PAIRED
/// Mã do `createInvite()` sinh ra sẽ ghép đôi thành công một lần.
class MockCoupleRepository implements CoupleRepository {
  MockCoupleRepository({
    required this.currentUser,
    this.latency = const Duration(milliseconds: 400),
  }) {
    _load();
  }

  final UserProfile? Function() currentUser;
  final Duration latency;

  /// Dùng static để chia sẻ trạng thái giữa các instance trong cùng runtime
  /// (ví dụ: khi logout/login lại hoặc trong widget test).
  ///
  /// LƯU Ý: Trên Web, đã hỗ trợ đồng bộ qua LocalStorage giúp test giữa 2 tab.
  static final Set<String> _consumedCodes = <String>{};
  static final Map<String, Couple> _coupleByUserId = <String, Couple>{};
  static String? _inviteCode;
  static String? _inviteOwnerId;
  static String? _inviteOwnerName;
  static DateTime? _inviteExpiresAt;
  static int _coupleSequence = 0;

  static void _save() {
    MockWebSync.save('mock_pairing', {
      'consumedCodes': _consumedCodes.toList(),
      'coupleByUserId': _coupleByUserId.map((k, v) => MapEntry(k, v.toJson())),
      'inviteCode': _inviteCode,
      'inviteOwnerId': _inviteOwnerId,
      'inviteOwnerName': _inviteOwnerName,
      'inviteExpiresAt': _inviteExpiresAt?.toIso8601String(),
      'coupleSequence': _coupleSequence,
    });
  }

  static void _load() {
    final data = MockWebSync.load('mock_pairing');
    if (data is Map) {
      if (data['consumedCodes'] is List) {
        _consumedCodes.addAll((data['consumedCodes'] as List).cast<String>());
      }
      if (data['coupleByUserId'] is Map) {
        final map = (data['coupleByUserId'] as Map).cast<String, dynamic>();
        map.forEach((k, v) {
          _coupleByUserId[k] = Couple.fromJson(v as Map<String, dynamic>);
        });
      }
      _inviteCode = data['inviteCode'] as String?;
      _inviteOwnerId = data['inviteOwnerId'] as String?;
      _inviteOwnerName = data['inviteOwnerName'] as String?;
      if (data['inviteExpiresAt'] != null) {
        _inviteExpiresAt = DateTime.tryParse(data['inviteExpiresAt'] as String);
      }
      _coupleSequence = data['coupleSequence'] as int? ?? 0;
    }
  }

  /// Xóa toàn bộ dữ liệu mock (dùng cho test).
  static void clear() {
    _consumedCodes.clear();
    _coupleByUserId.clear();
    _inviteCode = null;
    _inviteOwnerId = null;
    _inviteOwnerName = null;
    _inviteExpiresAt = null;
    _coupleSequence = 0;
    _save();
  }

  @override
  Future<CoupleInvite> createInvite() async {
    _load(); // Đảm bảo lấy code mới nhất từ tab khác
    await Future<void>.delayed(latency);
    final me = _requireUser();
    if (_coupleByUserId.containsKey(me.id)) {
      throw _error(409, 'ALREADY_PAIRED', 'Bạn đã tham gia một cặp đôi đang hoạt động.');
    }
    _inviteCode = _generateCode();
    _inviteOwnerId = me.id;
    _inviteOwnerName = me.displayName;
    _inviteExpiresAt = DateTime.now().toUtc().add(const Duration(hours: 24));
    _save();
    return CoupleInvite(inviteCode: _inviteCode!, expiresAt: _inviteExpiresAt!);
  }

  @override
  Future<Couple> join(String inviteCode) async {
    _load(); // Đảm bảo lấy code mới nhất từ tab khác
    await Future<void>.delayed(latency);
    final me = _requireUser();
    final code = inviteCode.trim().toUpperCase();

    if (_coupleByUserId.containsKey(me.id)) {
      throw _error(409, 'ALREADY_PAIRED', 'Bạn đã tham gia một cặp đôi đang hoạt động.');
    }
    switch (code) {
      case 'EXPYR3':
        throw _error(400, 'INVITE_EXPIRED', 'Mã ghép đôi đã hết hạn.');
      case 'US3D22':
        throw _error(400, 'INVALID_INVITE_CODE', 'Mã ghép đôi không đúng hoặc đã được sử dụng.');
      case 'S3LF22':
        throw _error(400, 'CANNOT_PAIR_SELF', 'Không thể tự ghép đôi với chính mình.');
      case 'PAYRD2':
        throw _error(409, 'INVITER_ALREADY_PAIRED', 'Người gửi mã đã thuộc về một cặp đôi khác.');
    }

    if (_consumedCodes.contains(code) || code != _inviteCode) {
      throw _error(400, 'INVALID_INVITE_CODE', 'Mã ghép đôi không đúng hoặc đã được sử dụng.');
    }
    if (_inviteExpiresAt == null || _inviteExpiresAt!.isBefore(DateTime.now().toUtc())) {
      _consumedCodes.add(code);
      _save();
      throw _error(400, 'INVITE_EXPIRED', 'Mã ghép đôi đã hết hạn.');
    }
    if (_inviteOwnerId == me.id) {
      throw _error(400, 'CANNOT_PAIR_SELF', 'Không thể tự ghép đôi với chính mình.');
    }
    if (_coupleByUserId.containsKey(_inviteOwnerId)) {
      throw _error(409, 'INVITER_ALREADY_PAIRED', 'Người gửi mã đã thuộc về một cặp đôi khác.');
    }

    final now = DateTime.now().toUtc();
    final couple = Couple(
      id: 'mock-couple-${++_coupleSequence}',
      status: 'ACTIVE',
      createdAt: now,
      members: [
        CoupleMember(
          id: _inviteOwnerId!,
          displayName: _inviteOwnerName ?? 'Người ấy',
          email: '',
          role: 'MEMBER',
          joinedAt: now,
        ),
        CoupleMember(
          id: me.id,
          displayName: me.displayName,
          email: me.email,
          role: 'MEMBER',
          joinedAt: now,
        ),
      ],
    );
    _consumedCodes.add(code);
    _coupleByUserId[_inviteOwnerId!] = couple;
    _coupleByUserId[me.id] = couple;
    _save();
    return couple;
  }

  @override
  Future<Couple?> current() async {
    _load();
    await Future<void>.delayed(latency);
    final me = currentUser();
    if (me == null) return null;
    return _coupleByUserId[me.id];
  }

  @override
  Future<void> unpair() async {
    _load();
    await Future<void>.delayed(latency);
    final me = _requireUser();
    final couple = _coupleByUserId[me.id];
    if (couple == null) {
      throw _error(404, 'COUPLE_NOT_FOUND', 'Người dùng hiện không thuộc cặp đôi nào đang hoạt động.');
    }
    _coupleByUserId.removeWhere((_, value) => value.id == couple.id);
    _save();
  }

  UserProfile _requireUser() {
    final me = currentUser();
    if (me == null) {
      throw _error(401, 'UNAUTHORIZED', 'Authentication is required to access this resource.');
    }
    return me;
  }

  static ApiException _error(int status, String code, String message) =>
      ApiException(statusCode: status, code: code, message: message);

  static const _alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static int _codeSeed = 0;

  static String _generateCode() {
    _codeSeed++;
    final buffer = StringBuffer();
    var value = DateTime.now().microsecondsSinceEpoch + _codeSeed * 7919;
    for (var index = 0; index < 6; index++) {
      buffer.write(_alphabet[value % _alphabet.length]);
      value = value ~/ 3 + 17;
    }
    return buffer.toString();
  }
}
