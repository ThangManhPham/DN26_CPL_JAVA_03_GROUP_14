import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/error/app_exception.dart';
import '../../auth/domain/user_profile.dart';
import '../domain/invite.dart';
import 'couple_repository.dart';

/// HTTP implementation của CoupleRepository.
class HttpCoupleRepository implements CoupleRepository {
  HttpCoupleRepository({
    required DioClient client,
    required SecureStorageService storage,
  })  : _client = client,
        _storage = storage;

  final DioClient _client;
  final SecureStorageService _storage;

  @override
  Future<InviteCode> createInvite() async {
    try {
      final response = await _client.request<Map<String, dynamic>>(
        '/api/v1/couple-invites',
        method: 'POST',
        authenticated: true,
      );
      return InviteCode.fromJson(response.data!);
    } on AppException {
      rethrow;
    } catch (e) {
      throw const AppException(message: 'Đã xảy ra lỗi không xác định.');
    }
  }

  @override
  Future<CoupleInfo> joinWithCode(String code) async {
    try {
      final response = await _client.request<Map<String, dynamic>>(
        '/api/v1/couples/join',
        method: 'POST',
        data: {'inviteCode': code.trim().toUpperCase()},
        authenticated: true,
      );
      return CoupleInfo.fromJson(response.data!);
    } on AppException catch (e) {
      if (e.code == 'INVITE_EXPIRED') {
        throw const InviteExpiredException();
      }
      if (e.code == 'INVITE_CODE_USED') {
        throw const InviteCodeUsedException();
      }
      if (e.code == 'SELF_PAIRING') {
        throw const SelfPairingException();
      }
      if (e.code == 'ALREADY_COUPLED') {
        throw const AlreadyCoupledException();
      }
      rethrow;
    } catch (e) {
      throw const AppException(message: 'Đã xảy ra lỗi không xác định.');
    }
  }

  @override
  Future<CoupleInfo?> getCurrentCouple() async {
    try {
      final response = await _client.request<Map<String, dynamic>>(
        '/api/v1/couples/me',
        method: 'GET',
        authenticated: true,
      );
      return CoupleInfo.fromJson(response.data!);
    } on AppException catch (e) {
      if (e.code != null) rethrow;
      // 404 means no couple yet
      return null;
    } catch (e) {
      throw const AppException(message: 'Đã xảy ra lỗi không xác định.');
    }
  }

  @override
  Future<void> unpair() async {
    try {
      await _client.request(
        '/api/v1/couples/me',
        method: 'DELETE',
        authenticated: true,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw const AppException(message: 'Đã xảy ra lỗi không xác định.');
    }
  }
}
