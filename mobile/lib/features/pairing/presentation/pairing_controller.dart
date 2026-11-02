import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/pairing_models.dart';
import '../data/pairing_repository.dart';

/// Trạng thái ghép đôi của người dùng đang đăng nhập (S1-09).
///
/// Controller này là "nguồn sự thật" cho router: khi [couple] chuyển từ
/// `null` sang có giá trị, Couple Home xuất hiện; khi hủy ghép đôi, app quay
/// về màn Pairing.
class PairingController extends ChangeNotifier {
  PairingController({required CoupleRepository repository})
    : _repository = repository;

  final CoupleRepository _repository;

  Couple? _couple;
  bool _loading = false;
  String? _error;

  Couple? get couple => _couple;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get isPaired => _couple != null;

  /// Nạp trạng thái ghép đôi hiện tại (`GET /api/v1/couples/me`).
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _couple = await _repository.current();
    } on ApiException catch (error) {
      _error = error.userMessage;
    } catch (_) {
      _error = 'Không thể tải thông tin cặp đôi. Vui lòng thử lại.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<CoupleInvite> createInvite() => _repository.createInvite();

  /// Ghép đôi bằng mã mời. Lỗi (mã sai/hết hạn/đã dùng/tự ghép/đã có couple)
  /// được ném nguyên trạng để màn nhập mã hiển thị đúng thông điệp.
  Future<void> join(String inviteCode) async {
    final joined = await _repository.join(inviteCode);
    _couple = joined;
    _error = null;
    notifyListeners();
  }

  /// Hủy ghép đôi. Backend hiện trả 501 `UNPAIRING_POLICY_PENDING`, UI sẽ
  /// bắt `ApiException` để báo rõ cho người dùng.
  Future<void> unpair() async {
    await _repository.unpair();
    _couple = null;
    _error = null;
    notifyListeners();
  }
}
