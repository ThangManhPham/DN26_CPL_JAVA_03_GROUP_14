import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';
import '../error/app_exception.dart';

/// Dio HTTP client với interceptor tự gắn Authorization header.
class DioClient {
  DioClient({required String baseUrl, required SecureStorageService storage})
      : _storage = storage,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: Duration(seconds: AppConfig.connectTimeout),
          receiveTimeout: Duration(seconds: AppConfig.receiveTimeout),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )) {
    _dio.interceptors.add(_AuthInterceptor(storage));
    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      logPrint: (o) {}, // Silent by default, avoid logging tokens
    ));
  }

  final Dio _dio;
  final SecureStorageService _storage;

  Dio get dio => _dio;

  /// Thực hiện request có xử lý lỗi chuẩn.
  Future<Response<T>> request<T>(
    String path, {
    String method = 'GET',
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    try {
      final token = authenticated ? await _storage.getToken() : null;
      return await _dio.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          headers: token != null
              ? {'Authorization': 'Bearer $token'}
              : null,
        ),
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  AppException _mapDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const NetworkException();
    }
    if (e.type == DioExceptionType.connectionError) {
      return const NetworkException();
    }
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    if (statusCode == 401) {
      return const UnauthenticatedException();
    }
    if (data is Map<String, dynamic>) {
      return AppException.fromJson(data);
    }
    if (statusCode != null) {
      return AppException(
        message: _httpMessage(statusCode),
        code: null,
      );
    }
    return const AppException(message: 'Đã xảy ra lỗi không xác định.');
  }

  String _httpMessage(int status) {
    switch (status) {
      case 400:
        return 'Yêu cầu không hợp lệ.';
      case 403:
        return 'Bạn không có quyền thực hiện thao tác này.';
      case 404:
        return 'Không tìm thấy dữ liệu.';
      case 409:
        return 'Xung đột dữ liệu. Vui lòng thử lại.';
      case 422:
        return 'Dữ liệu không hợp lệ.';
      case 429:
        return 'Bạn thao tác quá nhanh. Vui lòng thử lại sau.';
      case 500:
      default:
        return 'Máy chủ gặp lỗi. Vui lòng thử lại.';
    }
  }
}

/// Interceptor tự động gắn Bearer token vào header.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage);
  final SecureStorageService _storage;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Token expired or invalid — clear token, redirect to login
      // will be handled by AuthNotifier listener
      await _storage.deleteToken();
    }
    handler.next(err);
  }
}
