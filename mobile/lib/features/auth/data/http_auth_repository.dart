import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/error/app_exception.dart';
import '../../domain/user_profile.dart';
import 'auth_repository.dart';

/// HTTP implementation của AuthRepository.
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({
    required Dio dio,
    required SecureStorageService storage,
  })  : _dio = dio,
        _storage = storage;

  final Dio _dio;
  final SecureStorageService _storage;

  @override
  Future<({String token, UserProfile user})> login(
    String email,
    String password,
  ) async {
    try {
      final response = await _dio.post(
        '/api/v1/auth/login',
        data: {'email': email, 'password': password},
      );
      final data = response.data as Map<String, dynamic>;
      final token = data['accessToken'] as String;
      await _storage.saveToken(token);
      final user = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
      return (token: token, user: user);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<({String token, UserProfile user})> register(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      await _dio.post(
        '/api/v1/auth/register',
        data: {
          'email': email,
          'password': password,
          'displayName': displayName,
        },
      );
      // Registration may not return token, so login to get one.
      return login(email, password);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<UserProfile> getProfile(String token) async {
    try {
      final response = await _dio.get(
        '/api/v1/users/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return UserProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  AppException _mapDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const AppException(
          message: 'Không thể kết nối máy chủ. Kiểm tra mạng rồi thử lại.');
    }
    if (e.response?.statusCode == 401) {
      return const AppException(
          message: 'Email hoặc mật khẩu không đúng.');
    }
    if (e.response?.statusCode == 409) {
      return const AppException(
          message: 'Email này đã được sử dụng.', code: 'EMAIL_ALREADY_EXISTS');
    }
    if (e.response?.data is Map<String, dynamic>) {
      return AppException.fromJson(e.response!.data);
    }
    return const AppException(message: 'Đã xảy ra lỗi không xác định.');
  }
}
