import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'api_exception.dart';

/// HTTP client dùng chung: gắn Bearer token, báo 401 và chuẩn hóa lỗi.
class ApiClient {
  ApiClient({
    required String baseUrl,
    Dio? dio,
    this.onUnauthenticated,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 20),
               sendTimeout: const Duration(seconds: 20),
               contentType: Headers.jsonContentType,
               responseType: ResponseType.json,
             ),
           ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = this.token;
          if (token != null &&
              token.isNotEmpty &&
              !options.headers.containsKey('Authorization')) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) onUnauthenticated?.call();
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;

  /// Gọi khi server trả 401 để app xóa phiên và quay về Login. Có thể gán
  /// sau khi dựng xong `AuthController` (tránh phụ thuộc vòng).
  void Function()? onUnauthenticated;

  /// Token hiện tại; do `AuthController` đồng bộ qua `onTokenChanged`.
  String? token;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) => _json(
    () => _dio.get<dynamic>(
      path,
      queryParameters: query,
      options: _options(headers),
    ),
  );

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => _json(
    () => _dio.post<dynamic>(path, data: body, options: _options(headers)),
  );

  Future<Map<String, dynamic>> putJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => _json(
    () => _dio.put<dynamic>(path, data: body, options: _options(headers)),
  );

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => _json(
    () => _dio.patch<dynamic>(path, data: body, options: _options(headers)),
  );

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => _json(
    () => _dio.delete<dynamic>(path, data: body, options: _options(headers)),
  );

  /// Tải nội dung nhị phân (ảnh) qua endpoint có xác thực.
  Future<Uint8List> getBytes(String path, {Map<String, String>? headers}) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        options: _options(headers, responseType: ResponseType.bytes),
      );
      final data = response.data;
      return data == null ? Uint8List(0) : Uint8List.fromList(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  static Options _options(
    Map<String, String>? headers, {
    ResponseType? responseType,
  }) => Options(headers: headers, responseType: responseType);

  /// Header Bearer dùng cho các endpoint nhận token tường minh
  /// (ví dụ luồng auth trước khi token được lưu).
  static Map<String, String> bearer(String token) => {
    'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> _json(
    Future<Response<dynamic>> Function() send,
  ) async {
    try {
      final response = await send();
      return _asMap(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }
}
