import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/error/app_exception.dart';
import '../../domain/user_profile.dart';
import 'auth_repository.dart';

/// HTTP implementation của AuthRepository.
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({
    required DioClient client,
    required SecureStorageService storage,
  })  : _client = client,
        _storage = storage;

  final DioClient _client;
  final SecureStorageService _storage;

  @override
  Future<({String token, UserProfile user})> login(
    String email,
    String password,
  ) async {
    try {
      final response = await _client.request<Map<String, dynamic>>(
        '/api/v1/auth/login',
        method: 'POST',
        data: {'email': email, 'password': password},
        authenticated: false,
      );
      final data = response.data!;
      final token = data['accessToken'] as String;
      await _storage.saveToken(token);
      final user = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
      return (token: token, user: user);
    } on AppException {
      rethrow;
    } catch (e) {
      throw const AppException(message: 'Đã xảy ra lỗi không xác định.');
    }
  }

  @override
  Future<({String token, UserProfile user})> register(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      await _client.request<Map<String, dynamic>>(
        '/api/v1/auth/register',
        method: 'POST',
        data: {
          'email': email,
          'password': password,
          'displayName': displayName,
        },
        authenticated: false,
      );
      // Registration may not return token, so login to get one.
      return login(email, password);
    } on AppException {
      rethrow;
    } catch (e) {
      throw const AppException(message: 'Đã xảy ra lỗi không xác định.');
    }
  }

  @override
  Future<UserProfile> getProfile(String token) async {
    try {
      final response = await _client.request<Map<String, dynamic>>(
        '/api/v1/users/me',
        method: 'GET',
        authenticated: true,
      );
      return UserProfile.fromJson(response.data!);
    } on AppException {
      rethrow;
    } catch (e) {
      throw const AppException(message: 'Đã xảy ra lỗi không xác định.');
    }
  }
}
