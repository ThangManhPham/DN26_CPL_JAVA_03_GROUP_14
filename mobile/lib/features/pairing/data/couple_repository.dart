import '../domain/invite.dart';
import '../../auth/domain/user_profile.dart';

/// Abstract repository cho pairing — ghép đôi.
abstract class CoupleRepository {
  /// Tạo mã mời ghép đôi.
  Future<InviteCode> createInvite();

  /// Nhập mã mời và ghép đôi.
  Future<CoupleInfo> joinWithCode(String code);

  /// Lấy thông tin couple hiện tại.
  Future<CoupleInfo?> getCurrentCouple();

  /// Hủy ghép đôi.
  Future<void> unpair();
}
