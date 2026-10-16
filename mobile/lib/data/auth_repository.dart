import 'dart:convert';
import 'dart:io';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
  });
  final String id;
  final String email;
  final String displayName;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
  );
}

class AuthSession {
  const AuthSession({required this.token, required this.user});
  final String token;
  final UserProfile user;
  AuthSession withUser(UserProfile updated) =>
      AuthSession(token: token, user: updated);
}

class AuthException implements Exception {
  const AuthException(this.message, {this.code});
  final String message;
  final String? code;
}

abstract class AuthRepository {
  Future<AuthSession> login(String email, String password);
  Future<AuthSession> register(
    String email,
    String password,
    String displayName,
  );
  Future<UserProfile> getProfile(String token);
  Future<UserProfile> updateProfile(String token, String displayName);
}

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({required String baseUrl, HttpClient? client})
    : _baseUrl = Uri.parse(baseUrl),
      _client = client ?? HttpClient();
  final Uri _baseUrl;
  final HttpClient _client;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final request = await _client
          .openUrl(method, _baseUrl.resolve(path))
          .timeout(const Duration(seconds: 10));
      request.headers.contentType = ContentType.json;
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final content = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 10));
      final data = content.isEmpty ? <String, dynamic>{} : jsonDecode(content);
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(
          _messageFor(response.statusCode, data, authenticated: token != null),
          code: data['code'] as String?,
        );
      }
      return data;
    } on AuthException {
      rethrow;
    } on SocketException {
      throw const AuthException(
        'Không thể kết nối máy chủ. Kiểm tra mạng rồi thử lại.',
      );
    } on FormatException {
      throw const AuthException(
        'Dữ liệu máy chủ không hợp lệ. Vui lòng thử lại.',
      );
    } catch (_) {
      throw const AuthException(
        'Không thể hoàn tất yêu cầu. Vui lòng thử lại.',
      );
    }
  }

  String _messageFor(
    int status,
    Map<String, dynamic> data, {
    required bool authenticated,
  }) {
    if (data['code'] == 'EMAIL_ALREADY_EXISTS') {
      return 'Email này đã được sử dụng.';
    }
    if (status == 409) return 'Thông tin đã thay đổi. Vui lòng thử lại.';
    if (status == 401) {
      return authenticated
          ? 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'
          : 'Email hoặc mật khẩu không đúng.';
    }
    if (status == 400 || status == 422) {
      return data['message'] is String
          ? data['message'] as String
          : 'Thông tin chưa hợp lệ.';
    }
    if (status == 429) return 'Bạn thao tác quá nhanh. Vui lòng thử lại sau.';
    return 'Máy chủ gặp lỗi. Vui lòng thử lại.';
  }

  @override
  Future<AuthSession> login(String email, String password) async {
    final data = await _request(
      'POST',
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthSession(
      token: data['accessToken'] as String,
      user: UserProfile.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  @override
  Future<AuthSession> register(
    String email,
    String password,
    String displayName,
  ) async {
    await _request(
      'POST',
      '/api/v1/auth/register',
      body: {'email': email, 'password': password, 'displayName': displayName},
    );
    // The draft contract returns only a user on registration, so login supplies the token.
    return login(email, password);
  }

  @override
  Future<UserProfile> getProfile(String token) async {
    final data = await _request('GET', '/api/v1/users/me', token: token);
    return UserProfile.fromJson(data);
  }

  @override
  Future<UserProfile> updateProfile(String token, String displayName) async {
    final data = await _request(
      'PATCH',
      '/api/v1/users/me',
      token: token,
      body: {'displayName': displayName},
    );
    return UserProfile.fromJson(data);
  }
}

/// In-memory demo matching the Sprint 1 auth/profile contract.
class MockAuthRepository implements AuthRepository {
  final Map<String, ({String password, UserProfile user})> _users = {};
  int _id = 0;

  @override
  Future<AuthSession> register(
    String email,
    String password,
    String displayName,
  ) async {
    final key = email.toLowerCase();
    if (_users.containsKey(key)) {
      throw const AuthException(
        'Email này đã được sử dụng.',
        code: 'EMAIL_ALREADY_EXISTS',
      );
    }
    final user = UserProfile(
      id: 'mock-${++_id}',
      email: key,
      displayName: displayName,
    );
    _users[key] = (password: password, user: user);
    return AuthSession(token: 'mock-token-${user.id}', user: user);
  }

  @override
  Future<AuthSession> login(String email, String password) async {
    final account = _users[email.toLowerCase()];
    if (account == null || account.password != password) {
      throw const AuthException(
        'Email hoặc mật khẩu không đúng.',
        code: 'INVALID_CREDENTIALS',
      );
    }
    return AuthSession(
      token: 'mock-token-${account.user.id}',
      user: account.user,
    );
  }

  @override
  Future<UserProfile> getProfile(String token) async {
    for (final entry in _users.values) {
      if ('mock-token-${entry.user.id}' == token) return entry.user;
    }
    throw const AuthException(
      'Phiên đăng nhập đã hết hạn.',
      code: 'UNAUTHENTICATED',
    );
  }

  @override
  Future<UserProfile> updateProfile(String token, String displayName) async {
    for (final entry in _users.entries) {
      if ('mock-token-${entry.value.user.id}' == token) {
        final user = UserProfile(
          id: entry.value.user.id,
          email: entry.value.user.email,
          displayName: displayName,
        );
        _users[entry.key] = (password: entry.value.password, user: user);
        return user;
      }
    }
    throw const AuthException(
      'Phiên đăng nhập đã hết hạn.',
      code: 'UNAUTHENTICATED',
    );
  }
}
