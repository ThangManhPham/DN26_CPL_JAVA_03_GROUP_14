import 'dart:async';

import '../../../core/storage/secure_storage.dart';
import '../../../core/error/app_exception.dart';
import '../../auth/domain/user_profile.dart';
import '../domain/invite.dart';
import 'couple_repository.dart';

/// Mock implementation của CoupleRepository — dùng khi OURSPACE_USE_MOCK=true.
/// TODO: đồng bộ với contract v1 khi backend ready.
class MockCoupleRepository implements CoupleRepository {
  MockCoupleRepository({required SecureStorageService storage})
      : _storage = storage;

  final SecureStorageService _storage;
  String? _activeInviteCode;
  DateTime? _activeInviteExpiry;
  CoupleInfo? _couple;
  Timer? _inviteTimer;

  @override
  Future<InviteCode> createInvite() async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (_couple != null) {
      throw const AlreadyCoupledException();
    }

    // Generate 6-char code
    final code = _generateCode();
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));

    _activeInviteCode = code;
    _activeInviteExpiry = expiresAt;

    return InviteCode(inviteCode: code, expiresAt: expiresAt);
  }

  @override
  Future<CoupleInfo> joinWithCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final trimmed = code.trim().toUpperCase();

    if (trimmed.isEmpty) {
      throw const InviteCodeInvalidException();
    }

    if (_activeInviteCode == null || _activeInviteExpiry == null) {
      throw const InviteCodeInvalidException();
    }

    if (DateTime.now().isAfter(_activeInviteExpiry!)) {
      throw const InviteExpiredException();
    }

    if (trimmed != _activeInviteCode) {
      throw const InviteCodeInvalidException();
    }

    if (_couple != null) {
      throw const AlreadyCoupledException();
    }

    // Simulate pairing — create a mock couple
    final couple = CoupleInfo(
      id: 'couple-mock-1',
      status: 'ACTIVE',
      members: [
        const CoupleMember(id: 'user-mock-1', displayName: 'Bạn'),
        const CoupleMember(id: 'user-mock-2', displayName: 'Người kia'),
      ],
    );
    _couple = couple;
    _activeInviteCode = null;
    _activeInviteExpiry = null;

    return couple;
  }

  @override
  Future<CoupleInfo?> getCurrentCouple() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _couple;
  }

  @override
  Future<void> unpair() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _couple = null;
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now().millisecondsSinceEpoch;
    var seed = now;
    final code = List.generate(6, (_) {
      seed = (seed * 1664525 + 1013904223) & 0x7fffffff;
      return chars[seed % chars.length];
    }).join();
    return code;
  }
}
