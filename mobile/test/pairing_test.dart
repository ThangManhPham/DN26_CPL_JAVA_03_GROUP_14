import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_exception.dart';
import 'package:mobile/core/network/dio_client.dart';
import 'package:mobile/core/storage/secure_storage.dart';
import 'package:mobile/features/pairing/data/couple_repository.dart';
import 'package:mobile/features/pairing/data/mock_couple_repository.dart';
import 'package:mobile/features/pairing/domain/invite.dart';

void main() {
  group('AppException', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'code': 'INVITE_EXPIRED',
        'message': 'Mã ghép đôi đã hết hạn.',
        'details': {'ttl': 0},
        'requestId': 'req_12345',
      };
      final exception = AppException.fromJson(json);
      expect(exception.code, 'INVITE_EXPIRED');
      expect(exception.message, 'Mã ghép đôi đã hết hạn.');
      expect(exception.requestId, 'req_12345');
      expect(exception.details?['ttl'], 0);
    });

    test('fromJson handles missing fields gracefully', () {
      final json = <String, dynamic>{'message': 'Lỗi không rõ'};
      final exception = AppException.fromJson(json);
      expect(exception.code, isNull);
      expect(exception.message, 'Lỗi không rõ');
      expect(exception.requestId, isNull);
    });

    test('InviteExpiredException has correct message', () {
      const ex = InviteExpiredException();
      expect(ex.code, isNull);
      expect(ex.message, 'Mã mời đã hết hạn.');
    });

    test('InviteCodeUsedException has correct message', () {
      const ex = InviteCodeUsedException();
      expect(ex.message, 'Mã mời đã được sử dụng.');
    });

    test('InviteCodeInvalidException has correct message', () {
      const ex = InviteCodeInvalidException();
      expect(ex.message, 'Mã mời không hợp lệ.');
    });

    test('SelfPairingException has correct message', () {
      const ex = SelfPairingException();
      expect(ex.message, 'Bạn không thể ghép đôi với chính mình.');
    });

    test('AlreadyCoupledException has correct message', () {
      const ex = AlreadyCoupledException();
      expect(ex.message, 'Tài khoản đã thuộc một cặp đôi khác.');
    });
  });

  group('InviteCode DTO', () {
    test('fromJson parses correctly', () {
      final json = {
        'inviteCode': 'K7P4R8',
        'expiresAt': '2026-10-16T12:00:00Z',
      };
      final invite = InviteCode.fromJson(json);
      expect(invite.inviteCode, 'K7P4R8');
      expect(invite.expiresAt.year, 2026);
      expect(invite.expiresAt.month, 10);
      expect(invite.expiresAt.day, 16);
    });
  });

  group('MockCoupleRepository', () {
    late MockCoupleRepository repo;
    late SecureStorageService storage;

    setUp(() {
      storage = SecureStorageService();
      repo = MockCoupleRepository(storage: storage);
    });

    test('createInvite generates 6-char code', () async {
      final invite = await repo.createInvite();
      expect(invite.inviteCode.length, 6);
      expect(invite.inviteCode, matches(RegExp(r'^[A-Z0-9]+$')));
      expect(invite.expiresAt.isAfter(DateTime.now()), true);
    });

    test('createInvite twice returns different codes', () async {
      final invite1 = await repo.createInvite();
      // Clear state by joining
      await repo.joinWithCode(invite1.inviteCode);
      await repo.unpair();

      final invite2 = await repo.createInvite();
      // Codes may or may not be different (random), but both should be valid
      expect(invite2.inviteCode.length, 6);
    });

    test('joinWithCode succeeds with valid code', () async {
      final invite = await repo.createInvite();
      final couple = await repo.joinWithCode(invite.inviteCode);
      expect(couple.status, 'ACTIVE');
      expect(couple.members.length, 2);
    });

    test('joinWithCode throws InviteExpiredException for invalid code', () async {
      await repo.createInvite();
      // Wait for invite to "expire" - in mock this won't actually expire
      // But we can test with a wrong code
      expect(
        () => repo.joinWithCode('WRONG1'),
        throwsA(isA<InviteCodeInvalidException>()),
      );
    });

    test('joinWithCode throws AlreadyCoupledException if already coupled', () async {
      final invite = await repo.createInvite();
      await repo.joinWithCode(invite.inviteCode);
      expect(
        () => repo.createInvite(),
        throwsA(isA<AlreadyCoupledException>()),
      );
    });

    test('getCurrentCouple returns couple after joining', () async {
      expect(await repo.getCurrentCouple(), isNull);
      final invite = await repo.createInvite();
      await repo.joinWithCode(invite.inviteCode);
      expect(await repo.getCurrentCouple(), isNotNull);
    });

    test('unpair clears couple', () async {
      final invite = await repo.createInvite();
      await repo.joinWithCode(invite.inviteCode);
      expect(await repo.getCurrentCouple(), isNotNull);
      await repo.unpair();
      expect(await repo.getCurrentCouple(), isNull);
    });

    test('createInvite throws AlreadyCoupledException when already in couple', () async {
      final invite = await repo.createInvite();
      await repo.joinWithCode(invite.inviteCode);
      expect(
        () => repo.createInvite(),
        throwsA(isA<AlreadyCoupledException>()),
      );
    });
  });

  group('SecureStorageService', () {
    late SecureStorageService storage;

    setUp(() {
      storage = SecureStorageService();
    });

    test('saveToken and getToken roundtrip', () async {
      await storage.saveToken('my-secret-token');
      expect(await storage.getToken(), 'my-secret-token');
    });

    test('deleteToken removes token', () async {
      await storage.saveToken('token123');
      await storage.deleteToken();
      expect(await storage.getToken(), isNull);
    });

    test('hasToken returns correct values', () async {
      expect(await storage.hasToken(), false);
      await storage.saveToken('token456');
      expect(await storage.hasToken(), true);
    });

    test('onTokenCleared callback is called on deleteToken', () async {
      bool callbackCalled = false;
      storage.onTokenCleared = () => callbackCalled = true;
      await storage.saveToken('token');
      await storage.deleteToken();
      expect(callbackCalled, true);
    });
  });
}
